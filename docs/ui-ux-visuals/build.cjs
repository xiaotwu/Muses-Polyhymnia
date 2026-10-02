/* Regenerate offline SVG previews from the audit catalog. */
const fs=require('node:fs'),path=require('node:path');
const {render}=require('./render.js');
const catalog=JSON.parse(fs.readFileSync(path.join(__dirname,'../ui-ux-audit-options.json'),'utf8'));
const dir=path.join(__dirname,'samples');fs.mkdirSync(dir,{recursive:true});
for(const item of catalog)for(let i=0;i<item.options.length;i++)fs.writeFileSync(path.join(dir,`${item.id}${'ABCD'[i]}.svg`),render(item.id,i));
const htmlPath=path.join(__dirname,'../ui-ux-design-selector.html');
const html=fs.readFileSync(htmlPath,'utf8').replace(/(<script id="catalog" type="application\/json">)[\s\S]*?(<\/script>)/,(_,a,b)=>a+JSON.stringify(catalog).replace(/</g,'\\u003c')+b);
fs.writeFileSync(htmlPath,html);
console.log(`${catalog.length} areas, ${catalog.reduce((n,x)=>n+x.options.length,0)} SVG previews generated.`);
const escape=s=>String(s).replace(/[&<>\"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const overview=`<!doctype html><html lang="zh-Hans"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Muses · 256 样例总览</title><style>body{margin:24px;font:14px -apple-system,sans-serif;background:#f8f7f3;color:#252522}header{position:sticky;top:0;background:#f8f7f3ee;padding:10px 0;z-index:1}h1{font-size:25px}h2{font-size:18px;margin-top:30px}.grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px}a{color:#886633}figure{margin:0;border:1px solid #dedbd3;border-radius:9px;overflow:hidden;background:#fffefa}img{display:block;width:100%;aspect-ratio:1000/650}figcaption{padding:10px;font-size:12px;line-height:1.65}strong{display:block;margin-bottom:4px}@media(max-width:800px){.grid{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:480px){.grid{grid-template-columns:1fr}}</style><header><h1>Muses · 256 个概念样例</h1><p>结构与交互示意 / 虚拟数据 / 尚未实现 · <a href="../ui-ux-design-selector.html">返回选择页</a></p></header>${catalog.map(row=>`<section><h2><a href="../ui-ux-design-selector.html#${row.id}">${row.id} · ${escape(row.title)}</a></h2><div class="grid">${row.options.map((option,i)=>`<figure><a aria-label="选择 ${row.id}${'ABCD'[i]}" href="../ui-ux-design-selector.html#${row.id}"><img src="samples/${row.id}${'ABCD'[i]}.svg" alt="${escape(row.title)}方案 ${'ABCD'[i]}" width="1000" height="650"></a><figcaption><strong>${row.id}${'ABCD'[i]}</strong>${escape(option)}</figcaption></figure>`).join('')}</div></section>`).join('')}</html>`;
fs.writeFileSync(path.join(__dirname,'overview.html'),overview);
