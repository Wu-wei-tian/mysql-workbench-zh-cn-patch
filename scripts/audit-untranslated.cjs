// SPDX-License-Identifier: GPL-2.0-only
const fs=require('node:fs');
const untranslated=JSON.parse(fs.readFileSync('locales/untranslated.json','utf8'));
const preserved=untranslated.map(item=>({
 ...item,
 reason:item.english.includes('@keyframes')?'Executable CSS; never translate':
 item.english==='inherit'?'UI tooltip inheritance sentinel; must remain exact':
 item.english.startsWith('\\')?'MySQL Shell command; must remain executable':
 item.english.includes('(added cost)')?'Model identifier with pricing annotation; kept verbatim pending separate review':
 'Technical identifier, product name, unit, protocol, example, or abbreviation intentionally kept verbatim',
}));
fs.writeFileSync('locales/preserved.json',JSON.stringify(preserved,null,2));
console.log('Preserved candidates:',preserved.length);
