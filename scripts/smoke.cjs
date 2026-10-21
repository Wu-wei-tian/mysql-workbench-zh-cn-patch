// SPDX-License-Identifier: GPL-2.0-only
const { _electron: electron }=require('playwright');
const path=require('node:path');const fs=require('node:fs');
(async()=>{
  const app=await electron.launch({executablePath:path.resolve('build/app/MySQL Workbench.exe'),args:['--electron-user-data-dir='+path.resolve('build/test-profile'),'--ui-language=zh-CN'],timeout:60000});
  try{
    const page=await app.firstWindow({timeout:60000});
    page.on('dialog',d=>d.accept().catch(()=>{}));
    page.on('pageerror',error=>console.log('PAGE ERROR',error.message));
    await page.waitForLoadState('domcontentloaded');
    await page.waitForFunction(()=>document.body.innerText.length>50,{},{timeout:60000});
    await page.waitForTimeout(2000);
    await page.screenshot({path:'logs/startup-zh-CN.png'});
    console.log((await page.locator('body').innerText()).slice(0,16000));
    console.log('MENU',await app.evaluate(({Menu})=>Menu.getApplicationMenu().items.map(x=>x.label)));
    fs.writeFileSync('logs/dom.html',await page.content());
    fs.writeFileSync('logs/startup-result.json',JSON.stringify({title:await page.title(),language:await page.locator('html').getAttribute('lang'),body:await page.locator('body').innerText()},null,2));
  }finally{await Promise.race([app.close(),new Promise((_,reject)=>setTimeout(()=>reject(Error('Graceful close timed out')),20000))]).catch(async e=>{console.error(e.message);await app.evaluate(({app})=>app.exit(1)).catch(()=>{});});}
})().catch(e=>{console.error(e);process.exitCode=1;});
