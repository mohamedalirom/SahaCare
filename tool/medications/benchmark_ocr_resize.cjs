const {createWorker}=require('../../build/ocr-vendor/node_modules/tesseract.js');
const path=require('path');const fs=require('fs');
(async()=>{
 const root=path.resolve(__dirname,'../..');const measurements=[];
 const worker=await createWorker('fra+eng',1,{langPath:path.join(root,'web/ocr/data'),cacheMethod:'none'});
 try{for(const size of [250,300,350,400,450]){const results=[];
  for(const mode of ['original','resize']){const {data}=await worker.recognize(path.join(root,'build/ocr-quality',`size-${size}-${mode}.png`),{rotateAuto:true});results.push({mode,names:['doliprane','dafalgan'].filter(n=>data.text.toLowerCase().includes(n)).length});}
  measurements.push({size,results});
 }}finally{await worker.terminate();}
 fs.writeFileSync(path.join(root,'build/ocr-quality/resize-results.json'),JSON.stringify(measurements,null,2));
 console.log(JSON.stringify(measurements,null,2));
})().catch(e=>{console.error(e.message);process.exitCode=1;});
