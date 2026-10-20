(()=>{
 const boton=document.getElementById('btnImprimir'); let listo=false,imprimiendo=false;
 async function preparar(){
  if(document.fonts)await document.fonts.ready;
  await Promise.all([...document.images].map(i=>i.complete?Promise.resolve():new Promise(r=>{i.addEventListener('load',r,{once:true});i.addEventListener('error',r,{once:true});setTimeout(r,3000);}))); listo=true; if(boton)boton.disabled=false;
 }
 async function imprimir(){if(imprimiendo)return;imprimiendo=true;try{if(!listo)await preparar();window.print();}finally{imprimiendo=false;}}
 boton?.addEventListener('click',imprimir);
 window.addEventListener('load',async()=>{await preparar();if(document.body.dataset.auto==='true')imprimir();});
})();
