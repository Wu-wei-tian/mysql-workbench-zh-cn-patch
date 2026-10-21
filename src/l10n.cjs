// SPDX-License-Identifier: GPL-2.0-only
// Independent localization additions, 2026-10-21. Not an Oracle release.
const fs=require('node:fs');
const path=require('node:path');
const dictionary=require('./zh-CN.json');
let current='zh-CN', settingsFile, electronApp, nativeDialog;
exports.t=(text,args)=>{
  const translated=current==='zh-CN' && Object.hasOwn(dictionary,text)?dictionary[text]:text;
  return args?translated.replace(/\{(\d+)\}/g,(_,n)=>String(args[Number(n)])):translated;
};
exports.language=()=>current;
exports.initialize=(app,Menu,dialog)=>{
  electronApp=app; nativeDialog=dialog;
  settingsFile=path.join(app.getPath('userData'),'ui-language.json');
  try{const saved=JSON.parse(fs.readFileSync(settingsFile,'utf8'));if(saved.language==='en')current='en';}catch{}
  const cli=process.argv.find(a=>a.startsWith('--ui-language='));
  if(cli && ['zh-CN','en'].includes(cli.split('=')[1]))current=cli.split('=')[1];
  app.commandLine.appendSwitch('lang',current==='en'?'en-US':'zh-CN');
};
exports.applicationMenu=template=>{
  const roleNames={undo:'撤销',redo:'重做',cut:'剪切',copy:'复制',paste:'粘贴',delete:'删除',selectAll:'全选',toggleDevTools:'开发者工具',togglefullscreen:'切换全屏',minimize:'最小化',close:'关闭窗口',quit:'退出'};
  function visit(items){for(const item of items){if(item.role && !item.label && current==='zh-CN' && roleNames[item.role])item.label=roleNames[item.role];if(Array.isArray(item.submenu))visit(item.submenu);}}
  visit(template);
  template.push({label:'语言 / Language',submenu:[
    {label:'简体中文',type:'radio',checked:current==='zh-CN',click:()=>save('zh-CN')},
    {label:'English',type:'radio',checked:current==='en',click:()=>save('en')},
  ]});
  return template;
};
function save(language){
  try{
    fs.mkdirSync(path.dirname(settingsFile),{recursive:true});
    fs.writeFileSync(settingsFile,JSON.stringify({language}),'utf8');
    nativeDialog.showMessageBox({type:'info',title:'语言 / Language',message:'语言设置已保存。请保存工作并重新启动应用。\nLanguage saved. Save your work and restart the application.',buttons:['OK']});
  }catch(error){nativeDialog.showErrorBox('Language setting failed',error.message);}
}
