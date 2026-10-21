// SPDX-License-Identifier: GPL-2.0-only
// 2026-10-21: independent Simplified Chinese localization build tooling.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const parser = require('@babel/parser');
const traverse = require('@babel/traverse').default;
const root = path.resolve(__dirname, '..');
const original = process.env.WB_ORIGINAL || 'C:/Program Files/MySQL/MySQL Workbench';
const output = process.env.WB_OUTPUT || path.join(root, 'build/app');
const manifestFile = process.env.WB_MANIFEST || path.join(root,'build/patch-manifest.json');
const dictPath = path.join(root, 'locales/zh-CN.json');
const dict = fs.existsSync(dictPath) ? JSON.parse(fs.readFileSync(dictPath, 'utf8')) : {};
const displayKeys = new Set(['caption','label','title','tooltip','data-tooltip','aria-label','placeholder','description','message','detail','children','commandTitle','emptyMessage','loadingMessage','headerTooltip']);
for(const key of ['advancedActionCaption','heading','okButtonCaption','cancelButtonCaption'])displayKeys.add(key);
const chunks = /^(ApplicationHost-|index-|MigrationSubApp-|AnimatedProgressIndicator-|CommunicationDebugger-|FileViewer-|Search-).*\.js$/;
const files = fs.readdirSync(path.join(original,'resources/app/frontend/build/assets')).filter(x=>chunks.test(x)).map(x=>'resources/app/frontend/build/assets/'+x);
files.push(...fs.readdirSync(path.join(original,'resources/app/src')).filter(x=>x.endsWith('.cjs')).map(x=>'resources/app/src/'+x));
const entries = new Map(); const patches = [];
function keyOf(n) { return n?.computed ? '' : n?.key?.name || n?.key?.value; }
function isDisplay(p) {
  let q=p;
  // Only descend through expression branches, never through operators that test identifiers.
  for(let i=0;i<5 && q.parentPath;i++) {
    const parent=q.parentPath;
    if(parent.isObjectProperty() && q.key==='value') {
      if(displayKeys.has(keyOf(parent.node)))return true;
      if(keyOf(parent.node)==='value' && parent.parentPath.isObjectExpression())return parent.parentPath.node.properties.some(x=>keyOf(x)==='type' && x.value.value==='button');
      return false;
    }
    if(parent.isArrayExpression() || (parent.isConditionalExpression() && q.key!=='test') || (parent.isLogicalExpression() && q.key==='right')) {q=parent;continue;}
    if(parent.isCallExpression()) {
      const name=parent.node.callee.name;
      const member=parent.node.callee.property?.name;
      if(q.listKey==='arguments'){
        if(['summaryItem','renderStatusPill'].includes(member) && q.key===0)return true;
        if(['fieldRow','optionalFieldRow','statusSection'].includes(member) && q.key===1)return true;
        if(name && q.key===1){
          const init=parent.scope.getBinding(name)?.path?.node?.init;
          if(init?.type==='ConditionalExpression' && [init.consequent,init.alternate].every(x=>x.type==='MemberExpression' && ['fieldRow','optionalFieldRow'].includes(x.property.name)))return true;
        }
      }
      if(/^createDesktopCommand(State)?MenuItem$/.test(name || '') && q.listKey==='arguments' && q.key===1) return true;
      // Native errors have two fixed, display-only arguments.
      if(parent.node.callee.property?.name==='showErrorBox' && q.listKey==='arguments') return true;
    }
    return false;
  }
  return false;
}
function sha(b){return crypto.createHash('sha256').update(b).digest('hex');}
for(const file of files) {
  const input=fs.readFileSync(path.join(original,file),'utf8');
  const ast=parser.parse(input,{sourceType:'unambiguous'}); const edits=[];
  traverse(ast,{StringLiteral(p){
    const value=p.node.value;
    const reviewed=(value==='Database Connection Configuration' && p.parentPath.isVariableDeclarator()) || (value==='Release Notes' && p.parentPath.isArrayExpression() && p.parentPath.node.elements[1]?.value==='https://dev.mysql.com/doc/relnotes/workbench/en/');
    if(!/[A-Za-z]/.test(value) || !(isDisplay(p)||reviewed)) return;
    if(!entries.has(value))entries.set(value,[]);
    entries.get(value).push({file,line:p.node.loc.start.line,offset:p.node.start});
    if(Object.hasOwn(dict,value)) edits.push({start:p.node.start,end:p.node.end,text:`__wbT(${JSON.stringify(value)})`});
  },TemplateLiteral(p){
    if(!isDisplay(p))return;
    const key=p.node.quasis.map((x,i)=>(x.value.cooked??x.value.raw)+(i<p.node.expressions.length?'{'+i+'}':'')).join('');
    if(!/[A-Za-z]/.test(key))return;
    if(!entries.has(key))entries.set(key,[]);
    entries.get(key).push({file,line:p.node.loc.start.line,offset:p.node.start,template:true});
    if(Object.hasOwn(dict,key))edits.push({start:p.node.start,end:p.node.end,text:`__wbT(${JSON.stringify(key)}, [${p.node.expressions.map(x=>input.slice(x.start,x.end)).join(',')}])`});
  }});
  if(process.argv.includes('--extract'))continue;
  let text=input;
  for(const e of edits.sort((a,b)=>b.start-a.start))text=text.slice(0,e.start)+e.text+text.slice(e.end);
  if(edits.length) text='/* Modified 2026-10-21: independent zh-CN localization; GPL-2.0-only. */\n'+(file.endsWith('.cjs')?'const { t: __wbT } = require("./l10n.cjs");\n':'const __wbT = globalThis.__wbT;\n')+text;
  if(file==='resources/app/src/main.cjs') text=patchMain(text);
  if(text!==input){
    const dest=path.join(output,file);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,text);
    const back=path.join(root,'backup',file);fs.mkdirSync(path.dirname(back),{recursive:true});if(!fs.existsSync(back))fs.writeFileSync(back,input);
    patches.push({file,originalSha256:sha(input),patchedSha256:sha(text),occurrences:edits.length});
  }
}
const inventory=[...entries].sort(([a],[b])=>a.localeCompare(b)).map(([english,locations])=>({english,translation:dict[english]||null,locations}));
fs.writeFileSync(path.join(root,'locales/inventory.json'),JSON.stringify(inventory,null,2));
fs.writeFileSync(path.join(root,'locales/untranslated.json'),JSON.stringify(inventory.filter(x=>!x.translation),null,2));
const summary={candidateStrings:entries.size,translatedStrings:inventory.filter(x=>x.translation).length,translatedOccurrences:patches.reduce((s,x)=>s+x.occurrences,0),candidateOccurrences:inventory.reduce((s,x)=>s+x.locations.length,0)};
fs.writeFileSync(path.join(root,'logs/coverage.json'),JSON.stringify(summary,null,2));
if(!process.argv.includes('--extract')){
  const app=path.join(output,'resources/app');
  fs.copyFileSync(path.join(root,'src/l10n.cjs'),path.join(app,'src/l10n.cjs'));
  fs.copyFileSync(dictPath,path.join(app,'src/zh-CN.json'));
  const htmlFile='resources/app/frontend/build/index.html';
  const html=fs.readFileSync(path.join(original,htmlFile),'utf8');
  const changed=html.replace('<head>','<head>\n<!-- Modified 2026-10-21: zh-CN runtime. -->\n<script src="/localization.js"></script>');
  fs.writeFileSync(path.join(output,htmlFile),changed);
  patches.push({file:htmlFile,originalSha256:sha(html),patchedSha256:sha(changed)});
  const runtime='/* Independent localization, GPL-2.0-only, 2026-10-21. */\n'+fs.readFileSync(path.join(root,'src/renderer.js'),'utf8').replace('/*DICTIONARY*/',JSON.stringify(dict));
  fs.writeFileSync(path.join(app,'frontend/build/localization.js'),runtime);
  fs.writeFileSync(manifestFile,JSON.stringify({version:'26.7.0',revision:1,summary,patches},null,2));
}
console.log(summary);
function replaceOnce(text,from,to){if(text.split(from).length!==2)throw Error('Unsafe upstream mismatch: '+from);return text.replace(from,to);}
function patchMain(text){
  text=replaceOnce(text,'const isPrimaryInstance = app.requestSingleInstanceLock();',`// Modified: isolate standalone profiles; in-place patches retain the existing profile.
if (!explicitUserDataDir && fs.existsSync(path.join(appRootDir, "standalone-profile.marker"))) app.setPath("userData", path.join(app.getPath("appData"), "MySQL Workbench zh-CN"));
const localization = require("./l10n.cjs");
localization.initialize(app, Menu, dialog);
const isPrimaryInstance = app.requestSingleInstanceLock();`);
  text=replaceOnce(text,'const payload = await fs.promises.readFile(targetPath);',`let payload = await fs.promises.readFile(targetPath);
            if (path.basename(targetPath) === "index.html") {
                payload = Buffer.from(payload.toString("utf8").replace('<script src="/localization.js"></script>',
                    '<script>globalThis.__wbLanguage=' + JSON.stringify(localization.language()) + ';</script><script src="/localization.js"></script>'));
            }`);
  text=replaceOnce(text,'return Menu.buildFromTemplate(template);','return Menu.buildFromTemplate(localization.applicationMenu(template));');
  text=replaceOnce(text,'label: options.label ?? (options.stateId ? label : command?.label ?? label),','label: __wbT(options.label ?? (options.stateId ? label : command?.label ?? label)),');
  return text;
}
module.exports={isDisplay};
