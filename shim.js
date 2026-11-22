/* Adaptateur : l'interface appelle window.claude (db, user, downloads) ; ici c'est branché sur Supabase. */
(()=>{const C=window.APP_CONFIG||{};if(!C.SUPABASE_URL||/VOTRE/.test(C.SUPABASE_URL)){document.addEventListener('DOMContentLoaded',()=>document.body.innerHTML='<p style="padding:20px">Configure <b>config.js</b> (URL et clé anon Supabase).</p>');return}
const sb=supabase.createClient(C.SUPABASE_URL,C.SUPABASE_ANON_KEY);const E=e=>({code:e.code||'err',message:e.message||'Erreur'});
const mep=(async()=>{const{data:{session}}=await sb.auth.getSession();if(!session){location.href='login.html';return null}
 const{data}=await sb.from('profiles').select('id,name,role').eq('id',session.user.id).single();if(!data){await sb.auth.signOut();location.href='login.html';return null}return data})();
async function fetchColl(c){
 if(c==='people'){const{data,error}=await sb.from('profiles').select('id,joined');if(error)throw E(error);return data.map(x=>({id:x.id,joined:Date.parse(x.joined)}))}
 if(c==='roles'){const{data,error}=await sb.from('profiles').select('id,role');if(error)throw E(error);return data}
 let out=[],from=0;for(;;){let q=sb.from('docs').select('id,data').eq('coll',c);
  q=c==='log'?q.order('created_at',{ascending:false}).limit(500):q.order('id').range(from,from+999);
  const{data,error}=await q;if(error)throw E(error);out=out.concat(data.map(x=>({id:x.id,...x.data})));if(c==='log'||data.length<1000)break;from+=1000}
 return out}
const L={},T={};
async function poll(c){const l=L[c];if(!l||!l.cbs.size)return;try{const rows=await fetchColl(c),s=JSON.stringify(rows);if(s===l.last)return;l.last=s;
 const snap={docs:rows.map(({id,...d})=>({id,data:()=>d}))};l.cbs.forEach(f=>f[0](snap))}catch(e){l.cbs.forEach(f=>f[1]&&f[1](e))}}
const sched=c=>{clearTimeout(T[c]);T[c]=setTimeout(()=>poll(c),250)};
const pollAll=()=>Object.keys(L).forEach(poll);setInterval(()=>{if(!document.hidden)pollAll()},30000);document.addEventListener('visibilitychange',()=>{if(!document.hidden)pollAll()});
mep.then(m=>{if(!m)return;sb.channel('live').on('postgres_changes',{event:'*',schema:'public',table:'docs'},p=>sched((p.new&&p.new.coll)||(p.old&&p.old.coll)))
 .on('postgres_changes',{event:'*',schema:'public',table:'profiles'},()=>{sched('people');sched('roles')}).subscribe()});
const ok=({error})=>{if(error)throw E(error)};
const doc=p=>{const[c,i]=p.split('/');const done=x=>{sched(c);return x};
 const role=d=>sb.rpc('set_role',{target:i,new_role:d.role}).then(ok);
 return{set:async d=>{if(c==='people')return;if(c==='roles'){await role(d);return done()}ok(await sb.from('docs').insert({coll:c,id:i,data:d}));return done()},
  update:async d=>{if(c==='roles'){await role(d);return done()}ok(await sb.rpc('doc_update',{c,i,patch:d}));return done()},
  delete:async()=>{const{data,error}=await sb.from('docs').delete().eq('coll',c).eq('id',i).select();if(error)throw E(error);if(!data.length)throw{code:403,message:'Non autorisé'};return done()}}};
const dbapi={collection:c=>({onSnapshot(cb,err){(L[c]=L[c]||{cbs:new Set(),last:null}).cbs.add([cb,err]);L[c].last=null;poll(c);return()=>{}}}),doc};
let names=null;const user={async id(){return(await mep).id},async canEdit(){return(await mep).role==='admin'},
 async profiles(){const{data}=await sb.from('profiles').select('id,name');names=Object.fromEntries((data||[]).map(u=>[u.id,{name:u.name}]));return names}};
const downloads={async save({filename,data}){const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([data],{type:'application/json'}));a.download=filename;a.click()}};
window.claude={use:async n=>{await mep;return{db:dbapi,user,downloads}[n]||null}};
document.addEventListener('DOMContentLoaded',()=>{const m=document.getElementById('me');if(m){const b=document.createElement('button');b.textContent='Déconnexion';b.onclick=()=>sb.auth.signOut().then(()=>location.href='login.html');m.after(b)}})})();
