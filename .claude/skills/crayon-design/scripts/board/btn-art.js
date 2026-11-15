// InkButton art at an exact width (ink fill + ink marker), and its night look (nightControl fill + chalk). Usage: node btn-art.js <deps> <out> W  -> <out>/btn-ink-W.svg, btn-night-W.svg (height 96)
const path=require('path'),fs=require('fs'),{createRequire}=require('module');
const [deps,out,ws]=process.argv.slice(2); const w=+ws, h=96;
fs.mkdirSync(out,{recursive:true});
const rough=createRequire(path.join(path.resolve(deps),'package.json'))('roughjs'); const gen=rough.generator();
let seed=2101; const ns=()=>(seed+=37);
const toSvg=(d)=>gen.toPaths(d).map(p=>{const fill=p.fill&&p.fill!=='none'?p.fill:'none';const st=p.stroke&&p.stroke!=='none'?` stroke="${p.stroke}" stroke-width="${p.strokeWidth}" stroke-linecap="round" stroke-linejoin="round"`:'';return `<path d="${p.d}" fill="${fill}"${st}/>`;}).join('');
const rr=(x,y,w,h,r)=>`M${x+r} ${y}H${x+w-r}A${r} ${r} 0 0 1 ${x+w} ${y+r}V${y+h-r}A${r} ${r} 0 0 1 ${x+w-r} ${y+h}H${x+r}A${r} ${r} 0 0 1 ${x} ${y+h-r}V${y+r}A${r} ${r} 0 0 1 ${x+r} ${y}Z`;
const p=rr(6,6,w-12,h-12,26);
const doc=(inner)=>`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}">${inner}</svg>\n`;
seed=2101; fs.writeFileSync(path.join(out,`btn-ink-${w}.svg`),doc(`<path d="${p}" fill="#1E1B22"/>`+toSvg(gen.path(p,{seed:ns(),roughness:1.2,bowing:1.4,stroke:'#1E1B22',strokeWidth:4,disableMultiStroke:true}))));
seed=2101; fs.writeFileSync(path.join(out,`btn-night-${w}.svg`),doc(`<path d="${p}" fill="#2E2C4A"/>`+toSvg(gen.path(p,{seed:ns(),roughness:1.2,bowing:1.4,stroke:'#E9E4F5',strokeWidth:4,disableMultiStroke:true}))));
console.log('ok');
