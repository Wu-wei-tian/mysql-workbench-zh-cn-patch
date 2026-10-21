// SPDX-License-Identifier: GPL-2.0-only
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..');
const standalone=process.argv.includes('--standalone');
const manifest=JSON.parse(fs.readFileSync(path.join(root,standalone?'build/standalone-manifest.json':'build/patch-manifest.json'),'utf8'));
const payloadName=standalone?'standalone-payload':'patch-payload';
const appName=standalone?'app-standalone':'app';
const payload=path.join(root,'build',payloadName);fs.mkdirSync(payload,{recursive:true});
const additional=['resources/app/src/l10n.cjs','resources/app/src/zh-CN.json','resources/app/frontend/build/localization.js'];
for(const file of [...manifest.patches.map(x=>x.file),...additional]){
 const dest=path.join(payload,file);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(path.join(root,'build',appName,file),dest);
}
const lines=manifest.patches.map(p=>`Source: "..\\build\\${payloadName}\\${p.file.replaceAll('/','\\')}"; DestDir: "{app}\\${path.dirname(p.file).replaceAll('/','\\')}"; Flags: ignoreversion; BeforeInstall: VerifyOriginal('${p.file.replaceAll('/','\\')}', '${p.originalSha256}')`);
for(const f of additional) lines.push(`Source: "..\\build\\${payloadName}\\${f.replaceAll('/','\\')}"; DestDir: "{app}\\${path.dirname(f).replaceAll('/','\\')}"; Flags: ignoreversion`);
if(standalone)fs.writeFileSync(path.join(root,'installer/payload.iss'),lines.join('\n')+'\n');
const variant=standalone?'zip':'msi';
fs.writeFileSync(path.join(root,`installer/patch-payload-${variant}.iss`),lines.map(x=>(x.includes('BeforeInstall:')?x.replace(/; BeforeInstall:.*$/,'').replace('Flags: ignoreversion', 'Flags: ignoreversion uninsneveruninstall'):x)+`; Check: ${standalone?'IsZipRuntime':'IsMsiRuntime'}`).join('\n')+'\n');
const protect=manifest.patches.map(p=>`  CheckResource('${p.file.replaceAll('/','\\')}', '${p.originalSha256}', '${p.patchedSha256}');`);
fs.writeFileSync(path.join(root,`installer/resource-checks-${variant}.iss`),protect.join('\n')+'\n');
fs.writeFileSync(path.join(root,`installer/resource-backups-${variant}.iss`),protect.map(x=>x.replace('CheckResource','BackupResource')).join('\n')+'\n');
fs.writeFileSync(path.join(root,`installer/resource-restore-${variant}.iss`),manifest.patches.map(p=>`  RestoreResource('${p.file.replaceAll('/','\\')}', '${p.originalSha256}');`).join('\n')+'\n');
console.log('Packaged',manifest.patches.length,'modified files and',additional.length,'new files.');
