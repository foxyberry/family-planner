// Crayon paper cards at exact sizes (same recipe as ui-kit card-a/b/form). Usage: node card-art.js <deps> <out> WxH...  -> <out>/card-WxH.svg (white fill, ink line, radius 24)
const path=require('path'),fs=require('fs'),{createRequire}=require('module');
const [deps,out,...sizes]=process.argv.slice(2);
fs.mkdirSync(out,{recursive:true});
const rough=createRequire(path.join(path.resolve(deps),'package.json'))('roughjs'); const gen=rough.generator();
const INK='#1E1B22'; let seed=901;
const toSvg=(d)=>gen.toPaths(d).map(p=>{const fill=p.fill&&p.fill!=='none'?p.fill:'none';const st=p.stroke&&p.stroke!=='none'?` stroke="${p.stroke}" stroke-width="${p.strokeWidth}" stroke-linecap="round" stroke-linejoin="round"`:'';return `<path d="${p.d}" fill="${fill}"${st}/>`;}).join('');
const rr=(x,y,w,h,r)=>`M${x+r} ${y}H${x+w-r}A${r} ${r} 0 0 1 ${x+w} ${y+r}V${y+h-r}A${r} ${r} 0 0 1 ${x+w-r} ${y+h}H${x+r}A${r} ${r} 0 0 1 ${x} ${y+h-r}V${y+r}A${r} ${r} 0 0 1 ${x+r} ${y}Z`;
for(const s of sizes){const [w,h]=s.split('x').map(Number);seed+=37;
 const r=Math.min(24,(h-12)/2);
 const m=toSvg(gen.path(rr(6,6,w-12,h-12,r),{seed,roughness:1.2,bowing:1.4,stroke:INK,strokeWidth:4,disableMultiStroke:true,fill:'#FFFFFF',fillStyle:'solid'}));
 fs.writeFileSync(path.join(out,`card-${w}x${h}.svg`),`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}">${m}</svg>\n`);}
console.log('ok');
