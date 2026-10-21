// SPDX-License-Identifier: GPL-2.0-only
const fs=require('node:fs');
const inventory=JSON.parse(fs.readFileSync('locales/catalog-v1.json','utf8'));
const dictionary={};
for(const file of fs.readdirSync('locales').filter(x=>/^translation-\d+\.tsv$/.test(x))){
  for(const line of fs.readFileSync('locales/'+file,'utf8').split(/\r?\n/).filter(Boolean)){
    const pos=line.indexOf('\t');if(pos<1)throw Error('Bad TSV '+line);
    const index=Number(line.slice(0,pos));if(!inventory[index])throw Error('Invalid index');
    dictionary[inventory[index].english]=line.slice(pos+1).replace(/\\n/g,'\n');
  }
}
const extra=JSON.parse(fs.readFileSync('locales/catalog-v2-additions.json','utf8'));
for(const line of fs.readFileSync('locales/translation-extra.tsv','utf8').split(/\r?\n/).filter(Boolean)){
  const pos=line.indexOf('\t');dictionary[extra[Number(line.slice(0,pos))].english]=line.slice(pos+1);
}
fs.writeFileSync('locales/zh-CN.json',JSON.stringify(dictionary,null,2)+'\n');
const templates=JSON.parse(fs.readFileSync('locales/catalog-v3-additions.json','utf8'));
for(const line of fs.readFileSync('locales/translation-templates.tsv','utf8').split(/\r?\n/).filter(Boolean)){
  const pos=line.indexOf('\t');dictionary[templates[Number(line.slice(0,pos))].english]=line.slice(pos+1);
}
fs.writeFileSync('locales/zh-CN.json',JSON.stringify(dictionary,null,2)+'\n');
console.log('Imported',Object.keys(dictionary).length,'translations');
const admin=JSON.parse(fs.readFileSync('locales/catalog-v4-additions.json','utf8'));
for(const line of fs.readFileSync('locales/translation-admin.tsv','utf8').split(/\r?\n/).filter(Boolean)){
  const pos=line.indexOf('\t');dictionary[admin[Number(line.slice(0,pos))].english]=line.slice(pos+1);
}
fs.writeFileSync('locales/zh-CN.json',JSON.stringify(dictionary,null,2)+'\n');
console.log('Final dictionary:',Object.keys(dictionary).length);
