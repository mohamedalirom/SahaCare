// Fictional fixtures only. Does not read personal images or SQLite.
const {createWorker}=require('../../build/ocr-vendor/node_modules/tesseract.js');
const path=require('path');const fs=require('fs');
(async()=>{
 const root=path.resolve(__dirname,'../..');const results=[];
 const worker=await createWorker('fra+eng',1,{langPath:path.join(root,'web/ocr/data'),cacheMethod:'none'});
 try{
  for(const fixture of ['printed','printed-shadow','printed-small','printed-blurred','handwriting-print','handwriting-cursive']){
   for(const mode of ['original','contrast','document']){
    const started=Date.now();
    const {data}=await worker.recognize(path.join(root,'build/ocr-quality',`${fixture}-${mode}.png`),{rotateAuto:true});
    const normalized=data.text.toLowerCase().replace(/[^a-z]/g,'');
    const names=['doliprane','dafalgan'];
    results.push({fixture,mode,exactNames:names.filter(n=>normalized.includes(n)).length,expectedNames:2,technicalIndex:data.confidence,milliseconds:Date.now()-started,text:data.text});
   }
  }
 }finally{await worker.terminate();}
 fs.writeFileSync(path.join(root,'build/ocr-quality/results.json'),JSON.stringify(results,null,2));
 console.log(JSON.stringify(results.map(({text,...summary})=>summary),null,2));
})().catch(e=>{console.error(e.message);process.exitCode=1;});
