// SPDX-License-Identifier: GPL-2.0-only
// Archive creation is performed by Windows PowerShell's Compress-Archive.
const fs=require('node:fs'),path=require('node:path');
const out='build/source-package';fs.mkdirSync(out,{recursive:true});
function writable(dir){for(const e of fs.readdirSync(dir,{withFileTypes:true})){const p=path.join(dir,e.name);if(e.isDirectory())writable(p);else fs.chmodSync(p,0o666);}}
writable(out);
for(const dir of ['src','scripts','locales','installer','tests'])fs.cpSync(dir,path.join(out,dir),{recursive:true});
for(const file of ['package.json','package-lock.json','LICENSE.txt']){fs.copyFileSync(file,path.join(out,file));fs.chmodSync(path.join(out,file),0o666);}
fs.mkdirSync(path.join(out,'docs'),{recursive:true});
for(const file of ['README.txt','CHANGELOG.txt','BUILD.txt','TEST_REPORT.txt','SOURCE-LICENSE-NOTICE.txt','ANALYSIS.txt','READ ME BEFORE USE.txt'])fs.copyFileSync('dist/'+file,path.join(out,'docs',file));
