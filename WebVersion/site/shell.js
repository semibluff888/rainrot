'use strict';
(() => {
 const el = id => document.getElementById(id), canvas = el('canvas');
 const query = new URLSearchParams(location.search), qa = query.get('qa');
 const qaModes = {integration:['--test'],enemies:['--enemy-test'],walkthrough:['--walkthrough'],pacifist:['--walkthrough','--pacifist']};
 const testing = Object.hasOwn(qaModes,qa), diagnostic = testing || qa === 'manual';
 let callback, loading = false, running = false, state = {mode:'menu'}, unlockedAt = 0;
 const frameSamples=[];
 const call = (type, data) => { if(callback) data === undefined ? callback(type) : callback(type,data); };
 const log = (...args) => { if(!diagnostic) return; const n=el('qa-log');n.textContent += args.join(' ')+'\n';n.scrollTop=n.scrollHeight; };
 function syncUI(){
  const playing=state.started && !state.finished && state.mode==='';
  el('toolbar').hidden=!running || playing;
  el('recapture').hidden=!playing || !!document.pointerLockElement || testing;
  el('storage').hidden=!running || state.persistent!==false || playing;
 }
 function lock(){
  canvas.focus();
  if(!document.pointerLockElement){const p=canvas.requestPointerLock();if(p && p.catch)p.catch(error=>{log('POINTER_LOCK',error.name,error.message);syncUI();});}
 }
 window.RainrotWeb = {
  connectGame(fn){callback=fn;},
  update(value){state=value;running=true;el('entry').hidden=true;syncUI();},
  telemetry(value){if(diagnostic){el('telemetry').textContent=JSON.stringify({...value,pointerLocked:!!document.pointerLockElement,persistent:state.persistent});if(value.modal==='' && value.seconds>3)frameSamples.push({fps:value.fps,stage:value.stage,quality:value.quality});}},
  report(kind,result){if(diagnostic){el('qa-report').textContent=JSON.stringify({kind,...result,browser_frames:frameSamples},null,2);el('qa').dataset.result=String(result.failed===0 || result.passed===true);}},
  fullscreen(){if(!document.fullscreenElement)el('stage').requestFullscreen().catch(()=>{});else document.exitFullscreen().catch(()=>{});}
 };
 document.addEventListener('pointerlockchange',()=>{
  if(!document.pointerLockElement){unlockedAt=performance.now();call('unlock');}else call('lock');
  syncUI();
 });
 document.addEventListener('visibilitychange',()=>{if(document.hidden)call('hidden');});
 window.addEventListener('blur',()=>call('hidden'));
 canvas.addEventListener('contextmenu',e=>e.preventDefault());
 canvas.addEventListener('keydown',e=>{if(['Tab','Space','ArrowUp','ArrowDown','ArrowLeft','ArrowRight'].includes(e.code))e.preventDefault();});
 // A browser may deny capture immediately after Esc. This overlay supplies a new user gesture.
 el('recapture').onclick=()=>{lock();call('resume');};
 canvas.addEventListener('click',()=>{if(state.started && state.mode==='' && performance.now()-unlockedAt>120)lock();});
 el('fullscreen').onclick=()=>RainrotWeb.fullscreen();
 el('help').onclick=()=>{call('hidden');el('manual').showModal();};
 el('close-help').onclick=()=>el('manual').close();
 el('backup').onclick=()=>call('export_save');
 el('restore').onclick=()=>{call('hidden');el('import-dialog').showModal();};
 el('close-import').onclick=()=>el('import-dialog').close();
 el('choose-save').onclick=()=>el('save-file').click();
 el('apply-save').onclick=()=>{call('import_save',el('save-text').value);el('import-dialog').close();};
 el('save-file').onchange=async e=>{
  const file=e.target.files[0];if(!file)return;
  if(file.size>1024*1024){alert('记录文件过大，请选择游戏导出的 JSON 文件。');return;}
  el('save-text').value=await file.text();e.target.value='';
 };
 if(diagnostic)el('qa').hidden=false;
 el('start').onclick=async()=>{
  if(loading)return;loading=true;el('start').disabled=true;
  const missing=Engine.getMissingFeatures({threads:false});
  if(missing.length){el('loading').textContent='浏览器缺少：'+missing.join(', ')+'。请启用硬件加速，使用最新版 Chrome / Edge。';return;}
  el('progress').hidden=false;el('loading').textContent='正在接通疗养院线路…';
  const config={...window.RAINROT_BUILD,canvas,canvasResizePolicy:2,focusCanvas:true,ensureCrossOriginIsolationHeaders:false,
   args:testing?['--fixed-fps','60','--',...qaModes[qa]]:[],
   onPrint:log,onPrintError:(...a)=>{console.error(...a);log(...a);},
   onProgress:(current,total)=>{if(total>0){el('progress').value=current/total*100;el('loading').textContent=current>=total?'资源已就绪 · 正在构建病区灯光，首次进入请稍候…':'正在载入病区 · '+Math.round(current/total*100)+'%';}},
   onExit:code=>{running=false;syncUI();if(diagnostic)log('ENGINE_EXIT',code);else{el('entry').hidden=false;el('loading').textContent='游戏已关闭。刷新页面可重新进入。';}}
  };
  try{const engine=new Engine(config);await engine.startGame();canvas.focus();}
  catch(error){el('entry').hidden=false;el('loading').textContent='载入失败：'+error.message+'\n请通过启动脚本或 HTTP(S) 网址打开，检查网络后刷新重试。';log(error.message);}
 };
})();
