window.addEventListener('load',()=>setTimeout(()=>{try{
const root=document.querySelector('x-dc > div')||document.querySelector('body > div');
const R=e=>{const r=e.getBoundingClientRect();return {x:Math.round(r.left),y:Math.round(r.top),w:Math.round(r.width),h:Math.round(r.height)}};
const base=e=>{const m=document.createElement('span');m.style.cssText='display:inline-block;width:0;height:0;vertical-align:baseline';e.appendChild(m);const y=m.getBoundingClientRect().top;m.remove();return Math.round(y)};
const out=[];const seen=new Set();
const vis=e=>{const r=e.getBoundingClientRect();if(r.width<8||r.height<8)return false;const cs=getComputedStyle(e);return cs.visibility!=='hidden'&&cs.display!=='none'&&+cs.opacity>0.05};
const inClip=e=>{let p=e.parentElement;while(p&&p!==root){const cs=getComputedStyle(p);if(cs.overflow==='hidden'){const a=p.getBoundingClientRect(),b=e.getBoundingClientRect();if(b.bottom<=a.top||b.top>=a.bottom||b.right<=a.left||b.left>=a.right)return false}p=p.parentElement}return true};
function glyph(e){const rg=document.createRange();rg.selectNodeContents(e);const r=rg.getBoundingClientRect();return {x:Math.round(r.left),y:Math.round(r.top),w:Math.round(r.width),h:Math.round(r.height)}}
function add(e,kind,extra,keepKids){if(seen.has(e)||!vis(e)||!inClip(e))return;seen.add(e);const o={kind,...(kind==='text'||kind==='title'?glyph(e):R(e)),...extra};const t=(e.getAttribute('aria-label')||e.textContent||'').trim().replace(/\s+/g,' ');if(t)o.text=t.slice(0,48);out.push(o);if(!keepKids)[...e.querySelectorAll('*')].forEach(c=>seen.add(c));}
// interactive and named parts first
root.querySelectorAll('.bus-roll').forEach(e=>add(e,'mover',{}));
root.querySelectorAll('.bubble').forEach(e=>add(e,'bubble',{}));
root.querySelectorAll('div').forEach(e=>{const bg=e.style.background||'';if(bg.includes('ea501b3e'))add(e,'card',{},e.getAttribute('role')!=='listbox')});
root.querySelectorAll('[role=tab]').forEach(e=>{if(e.closest('[role=tablist]')&&e.getBoundingClientRect().height===100){add(e,'row',{},true);const sp=e.querySelector(':scope > span');if(sp)add(sp,'ring',{})}});
root.querySelectorAll('[role=slider]').forEach(e=>add(e,'slide',{},true));
root.querySelectorAll('h1').forEach(e=>add(e,'title',{base:base(e),font:parseInt(getComputedStyle(e).fontSize)}));
root.querySelectorAll('a, button, [role=tab], [role=radio]').forEach(e=>{
 const r=e.getBoundingClientRect();let kind='button';
 const cls=(e.className||'')+'';
 if(cls.includes('btn-round')||cls.includes('bg-btnround'))kind='back';
 else if(e.getAttribute('role')==='tab')kind='row';
 else if(Math.round(r.width)===112&&Math.round(r.height)===112)kind='circle';
 else if(cls.includes('btn-ink'))kind='primary';
 else if(e.querySelector('.slider-864,.slider-wide,.slider,.slider-done'))kind='slide';
 else if(cls.includes('pill')||(e.textContent||'').includes('All done'))kind='pill';
 else if(cls.includes('slot'))kind='choice';
 else if(cls.includes('day-'))kind='chip';
 else if(cls.includes('tab-'))kind='tab';
 add(e,kind,{});
});
root.querySelectorAll('[class*="field"]').forEach(e=>add(e,'field',{}));
root.querySelectorAll('.lbl').forEach(e=>add(e,'label',{}));
root.querySelectorAll('svg').forEach(e=>{if(e.getBoundingClientRect().width>200)add(e,'drawing',{})});
root.querySelectorAll('img').forEach(e=>{const r=e.getBoundingClientRect();if(r.width>=28)add(e,'picture',{})});
// leaf text
root.querySelectorAll('span, p, div').forEach(e=>{if([...e.childNodes].some(n=>n.nodeType===3&&n.textContent.trim())){const fs=parseInt(getComputedStyle(e).fontSize);add(e,'text',{base:base(e),font:fs})}});
document.body.setAttribute('data-x',JSON.stringify(out));}catch(err){document.body.setAttribute('data-x',JSON.stringify([{kind:'ERR',x:0,y:0,w:0,h:0,text:String(err)+' '+err.stack}]))}
},1500));
