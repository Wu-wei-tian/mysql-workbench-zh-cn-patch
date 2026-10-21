// SPDX-License-Identifier: GPL-2.0-only
// Development-only interactive Playwright harness. Never included in the app.
const { _electron:electron }=require('playwright');
const path=require('node:path'),fs=require('node:fs'),readline=require('node:readline');
(async()=>{
 const ea=await electron.launch({executablePath:path.resolve('build/app/MySQL Workbench.exe'),args:['--electron-user-data-dir='+path.resolve('build/test-profile')],timeout:45000});
 const pg=await ea.firstWindow();
 pg.on('dialog',d=>d.accept().catch(()=>{}));
 pg.on('pageerror',e=>console.error('PAGE ERROR',e.message));
 await pg.waitForFunction(()=>document.body.innerText.length>50,{},{timeout:45000});
 console.log('READY',await pg.locator('body').innerText());
 const rl=readline.createInterface({input:process.stdin});
 for await(const line of rl){try{console.log(await eval('(async()=>{'+line+'})()'));}catch(e){console.log('ERROR',e.stack);}}
 await ea.close();
})().catch(e=>{console.error(e);process.exitCode=1;});
