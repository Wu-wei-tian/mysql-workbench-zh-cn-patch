// SPDX-License-Identifier: GPL-2.0-only
const {_electron:electron}=require('playwright');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');const results=[];
const variant=process.argv[2]||'msi';
const executable=process.env.WB_TEST_EXE||path.join(root,variant==='zip'?'build/app-standalone/MySQL Workbench.exe':'build/app/MySQL Workbench.exe');
const profile=path.join(root,'build/e2e-'+variant+'-'+Date.now());
const sql="CREATE DATABASE IF NOT EXISTS localization_qa;\nCREATE TABLE IF NOT EXISTS localization_qa.`Language` (id INT PRIMARY KEY, label VARCHAR(80) CHARACTER SET utf8mb4);\nINSERT INTO localization_qa.`Language` (id,label) VALUES (1, 'Save'), (2, '简体中文测试') ON DUPLICATE KEY UPDATE label=VALUES(label);\nSELECT id, label FROM localization_qa.`Language` ORDER BY id;";
let app,page;
const record=(name,details={})=>{results.push({name,status:'PASS',...details});console.log('PASS',name);};
async function menu(top,label){await app.evaluate(({Menu},args)=>{const parent=Menu.getApplicationMenu().items.find(x=>x.label===args.top);const item=parent?.submenu?.items.find(x=>x.label===args.label);if(!item||!item.enabled)throw Error('Menu item unavailable: '+args.label);item.click();},{top,label});}
async function launch(language){
 app=await electron.launch({executablePath:executable,args:['--electron-user-data-dir='+profile,'--ui-language='+language],timeout:45000});
 page=await app.firstWindow();page.on('dialog',d=>d.accept().catch(()=>{}));
 page.on('pageerror',e=>results.push({name:'renderer-error',status:'FAIL',message:e.message}));
 await page.waitForFunction(()=>document.body.innerText.length>50,{},{timeout:45000});
}
async function close(){
 const closed=app.waitForEvent('close',{timeout:20000});
 await app.evaluate(({app})=>app.quit()).catch(()=>{});
 await closed;record('graceful-exit');
}
(async()=>{
 await launch('zh-CN');
 assert.equal(await page.locator('html').getAttribute('lang'),'zh-CN');
 await page.getByText('数据库连接',{exact:true}).waitFor();
 await page.screenshot({path:`logs/${variant}-home-final.png`});record('startup-home-chinese');
 await page.locator('#newConnectionButton').click();
 await page.locator('#caption').waitFor();
 await page.locator('#caption').fill('Localization QA');
 await page.locator('#hostName').fill('127.0.0.1');await page.locator('#port').fill('13367');await page.locator('#userName').fill('root');
 await page.screenshot({path:`logs/${variant}-connection-final.png`});
 await page.locator('#ok').click();await page.getByText('Localization QA',{exact:true}).last().dblclick();
 // Only the deliberately empty credential of our isolated test fixture is submitted.
 for(let i=0;i<80;i++){
   const no=page.getByRole('button',{name:'No',exact:true});
   if(await no.count()){await no.click();await page.waitForTimeout(1000);continue;}
   const passwordPrompt=page.locator('input[type="password"]:visible');
   if(await passwordPrompt.count()){await page.locator('#ok').click();await page.waitForTimeout(1000);continue;}
   if(await page.locator('textarea.inputarea').count()){
     await page.waitForTimeout(1000);
     if(!await passwordPrompt.count() && !await no.count())break;
   }
   await page.waitForTimeout(350);
 }
 await page.locator('textarea.inputarea').waitFor({timeout:15000});record('connect-isolated-mysql-8.4.13');
 await page.locator('textarea.inputarea').focus();await page.keyboard.insertText(sql);
 await page.getByRole('button',{name:'运行',exact:true}).click();
 await page.locator('.tabulator-cell').filter({hasText:'简体中文测试'}).first().waitFor({timeout:15000});
 assert.ok(await page.locator('.tabulator-cell').filter({hasText:/^Save$/}).count()>0);
 await page.screenshot({path:`logs/${variant}-sql-final.png`});record('ddl-insert-select-unicode-and-data-preservation');
 const scriptPath=path.join(root,`build/qa-${variant}.sql`);
 await app.evaluate(({dialog},filePath)=>{dialog.showSaveDialog=async()=>({canceled:false,filePath});},scriptPath);
 await menu('文件','保存');
 for(let i=0;i<40&&!fs.existsSync(scriptPath);i++)await page.waitForTimeout(100);
 assert.ok(fs.readFileSync(scriptPath,'utf8').includes("'Save'"));record('save-sql-preserves-source');
 for(const [label,id]of [['服务器状态','server'],['用户账户','users'],['客户端连接','clients'],['性能报告','performance']]){
   await menu('数据库',label);await page.waitForTimeout(650);
   assert.ok((await page.locator('body').innerText()).includes(label));
   await page.screenshot({path:`logs/${variant}-${id}-final.png`});record('open-'+id);
 }
 // Verify persisted language selection without a modal, then relaunch with no override.
 await app.evaluate(({dialog,Menu})=>{dialog.showMessageBox=async()=>({response:0});Menu.getApplicationMenu().items.find(x=>x.label==='语言 / Language').submenu.items.find(x=>x.label==='English').click();});
 assert.equal(JSON.parse(fs.readFileSync(path.join(profile,'ui-language.json'),'utf8')).language,'en');record('persist-language-choice');
 await close();
 app=await electron.launch({executablePath:executable,args:['--electron-user-data-dir='+profile],timeout:45000});
 page=await app.firstWindow();page.on('dialog',d=>d.accept().catch(()=>{}));await page.waitForFunction(()=>document.body.innerText.length>50,{},{timeout:45000});
 assert.equal(await page.locator('html').getAttribute('lang'),'en');
 assert.ok((await app.evaluate(({Menu})=>Menu.getApplicationMenu().items.map(x=>x.label))).includes('File'));
 await page.screenshot({path:`logs/${variant}-english-final.png`});record('english-restart');await close();
 if(results.some(x=>x.status==='FAIL'))throw Error('Renderer errors found');
})().catch(async error=>{results.push({name:'e2e',status:'FAIL',message:error.stack});console.error(error);if(page)await page.screenshot({path:`logs/${variant}-failure.png`,timeout:3000}).catch(()=>{});if(app)await app.evaluate(({app})=>app.exit(1)).catch(()=>{});process.exitCode=1;}).finally(()=>fs.writeFileSync(`logs/e2e-${variant}.json`,JSON.stringify(results,null,2)));
