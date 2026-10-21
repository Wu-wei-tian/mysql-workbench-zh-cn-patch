// SPDX-License-Identifier: GPL-2.0-only
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const parser=require('@babel/parser'),traverse=require('@babel/traverse').default;
const dictionary=JSON.parse(fs.readFileSync('locales/zh-CN.json','utf8'));
test('all template translations preserve placeholder multiplicity',()=>{
 for(const [en,zh] of Object.entries(dictionary))assert.deepEqual((zh.match(/\{\d+\}/g)||[]).sort(),(en.match(/\{\d+\}/g)||[]).sort(),en);
});
test('renderer lookup has English fallback and preserves arbitrary data',()=>{
 const source=fs.readFileSync('src/renderer.js','utf8').replace('/*DICTIONARY*/',JSON.stringify(dictionary));
 for(const language of ['zh-CN','en']){
  const sandbox={document:{documentElement:{}},__wbLanguage:language};vm.createContext(sandbox);vm.runInContext(source,sandbox);
  assert.equal(sandbox.__wbT('Save'),language==='zh-CN'?'保存':'Save');
  assert.equal(sandbox.__wbT('SELECT `Language` FROM test WHERE label = \'Save\''),'SELECT `Language` FROM test WHERE label = \'Save\'');
  assert.equal(sandbox.__wbT('Unknown user-owned object'),'Unknown user-owned object');
  assert.equal(sandbox.__wbT('Select up to {0} tags to display with the connection.',[4]),language==='zh-CN'?'最多选择 4 个标签，与连接一起显示。':'Select up to 4 tags to display with the connection.');
 }
});
function clean(n){if(Array.isArray(n))return n.map(clean);if(!n||typeof n!=='object')return n;const out={};for(const [k,v]of Object.entries(n))if(!['start','end','loc','extra','leadingComments','trailingComments','innerComments','comments','tokens'].includes(k))out[k]=clean(v);return out;}
function key(n){return n.quasis.map((q,i)=>q.value.cooked+(i<n.expressions.length?'{'+i+'}':'')).join('');}
for(const [manifestName,appRoot,originalRoot]of [
 ['build/patch-manifest.json','build/app',process.env.WB_ORIGINAL||'C:/Program Files/MySQL/MySQL Workbench'],
 ['build/standalone-manifest.json','build/app-standalone','build/official-zip']
]){
 if(!fs.existsSync(manifestName))continue;
 const manifest=JSON.parse(fs.readFileSync(manifestName,'utf8'));
 for(const patch of manifest.patches.filter(x=>x.file.endsWith('.js') && x.file.includes('/assets/'))){
  test('AST behavior preservation: '+appRoot+'/'+path.basename(patch.file),()=>{
   const backup=path.join(originalRoot,'localization/original',patch.file);
   const originalFile=fs.existsSync(backup)?backup:path.join(originalRoot,patch.file);
   const originalText=fs.readFileSync(originalFile,'utf8');
   assert.equal(require('node:crypto').createHash('sha256').update(originalText).digest('hex'),patch.originalSha256,'Original test input fingerprint');
   const original=parser.parse(originalText,{sourceType:'module'});
   const changed=parser.parse(fs.readFileSync(path.join(appRoot,patch.file),'utf8'),{sourceType:'module'});
   const templates=new Map();traverse(original,{TemplateLiteral(p){templates.set(key(p.node),p.node);}});
   traverse(changed,{CallExpression(p){if(p.node.callee.name==='__wbT'){
    const args=p.node.arguments;
    if(args.length===1)p.replaceWith({type:'StringLiteral',value:args[0].value});
    else {const n=structuredClone(templates.get(args[0].value));assert.ok(n,args[0].value);n.expressions=args[1].elements;p.replaceWith(n);}
   }}});
   changed.program.body=changed.program.body.filter(n=>!(n.type==='VariableDeclaration'&&n.declarations[0].id.name==='__wbT'));
   assert.deepEqual(clean(changed.program),clean(original.program));
  });
 }
}
test('patch uninstall never deletes upstream modified files',()=>{
 for(const name of ['msi','zip']){
  const lines=fs.readFileSync('installer/patch-payload-'+name+'.iss','utf8').trim().split('\n');
  const manifest=JSON.parse(fs.readFileSync(name==='msi'?'build/patch-manifest.json':'build/standalone-manifest.json','utf8'));
  for(const p of manifest.patches){const line=lines.find(x=>x.includes(p.file.replaceAll('/','\\')));assert.ok(line?.includes('uninsneveruninstall'),p.file);}
 }
});
test('release payload contains no build-host absolute path',()=>{
 for(const p of ['src/l10n.cjs','src/renderer.js','installer/setup.iss','installer/patch.iss'])assert.ok(!/C:[/\\]Users[/\\]21910/i.test(fs.readFileSync(p,'utf8')),p);
});
