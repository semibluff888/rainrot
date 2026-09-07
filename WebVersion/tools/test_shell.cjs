// Exercises shipped shell event handling with a minimal DOM, without a browser driver.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const source=fs.readFileSync(require('node:path').join(__dirname,'../site/shell.js'),'utf8');

function page({width=1920,height=1080,dpr=1,query=''}={}){
 const elements=new Map(),events={},docEvents={};let frame,observer,media,config;
 const stageRect={width,height,left:0,top:0};
 const node=id=>{
  if(!elements.has(id))elements.set(id,{width:300,height:150,clientWidth:width,clientHeight:height,style:{},dataset:{},hidden:true,textContent:'',focus(){},addEventListener(){},getBoundingClientRect(){return stageRect;}});
  return elements.get(id);
 };
 const document={getElementById:node,hasFocus:()=>true,hidden:false,addEventListener:(k,f)=>(docEvents[k]??=[]).push(f)};
 const window={devicePixelRatio:dpr,addEventListener:(k,f)=>(events[k]??=[]).push(f)};
 const context={window,document,location:{search:query},URLSearchParams,console,navigator:{userAgent:'shell-test'},performance:{now:()=>100},
  requestAnimationFrame:f=>{frame=f;return 1;},
  matchMedia:()=>{media={addEventListener:(k,f)=>{media.change=f;},removeEventListener:()=>{}};return media;},
  ResizeObserver:class{constructor(f){observer=f;}observe(){}},
  Engine:class{constructor(c){config=c;}static getMissingFeatures(){return [];}async startGame(){}}
 };
 vm.runInNewContext(source,context);
 const flush=()=>{if(frame){const f=frame;frame=undefined;f();}};
 return {node,window,document,bridge:window.RainrotWeb,get config(){return config;},
  size:()=>[node('canvas').width,node('canvas').height],
  resize(w,h){stageRect.width=w;stageRect.height=h;observer();flush();},
  dpr(value){window.devicePixelRatio=value;media.change();flush();},
  emit(name,doc=false){for(const f of (doc?docEvents:events)[name]??[])f();flush();}};
}
test('physical buffer caps high-DPI and 4K, retaining layout and aspect ratio',()=>{
 const p=page({width:2560,height:1440,dpr:2});
 assert.deepEqual(p.size(),[1920,1080]);
 assert.equal(p.node('canvas').style.width,undefined);
 p.resize(3440,1440);assert.deepEqual(p.size(),[1920,803]);
 p.resize(800,600);assert.deepEqual(p.size(),[1440,1080]);
 p.dpr(1);assert.deepEqual(p.size(),[800,600]);
 p.resize(0,0);assert.deepEqual(p.size(),[800,600]);
 p.resize(1280,720);p.emit('fullscreenchange',true);assert.deepEqual(p.size(),[1280,720]);
});
test('ordinary play has no diagnostics and Godot does not override canvas sizing',async()=>{
 const p=page();assert.equal(p.bridge.diagnostic,false);
 await p.node('start').onclick();
 assert.equal(p.config.canvasResizePolicy,0);
 assert.deepEqual(Array.from(p.config.args),[]);
});
test('benchmark uses wall time, quality defaults safely, and reports invalidated runs',async()=>{
 const p=page({query:'?qa=benchmark&quality=2'});
 await p.node('start').onclick();
 assert.deepEqual(Array.from(p.config.args),['--','--benchmark','--benchmark-quality=2']);
 p.bridge.update({mode:'',started:true});
 p.bridge.report('benchmark_progress',{scene:'corridor'});
 p.emit('blur');p.resize(1280,720);
 p.bridge.report('benchmark',{passed:true});
 const r=JSON.parse(p.node('qa-report').textContent);
 assert.equal(r.valid,false);assert.equal(p.node('qa').dataset.result,'false');
 assert.ok(r.invalid_reasons.includes('window_blurred'));assert.ok(r.invalid_reasons.includes('canvas_resized'));
 assert.deepEqual(r.browser.canvas,[1280,720]);
 const fallback=page({query:'?qa=benchmark&quality=bad'});await fallback.node('start').onclick();
 assert.equal(fallback.config.args.at(-1),'--benchmark-quality=1');
});
test('functional QA retains fixed simulation and diagnostic samples are bounded',async()=>{
 const p=page({query:'?qa=integration'});await p.node('start').onclick();
 assert.deepEqual(Array.from(p.config.args),['--fixed-fps','60','--','--test']);
 for(let i=0;i<1900;i++)p.bridge.telemetry({modal:'',seconds:10,fps:60});
 p.bridge.report('integration',{failed:0});assert.equal(JSON.parse(p.node('qa-report').textContent).browser_frames.length,1800);
});
test('visibility events do not resume gameplay or recapture the pointer',()=>{
 const p=page(),calls=[];p.bridge.connectGame((...a)=>calls.push(a[0]));
 p.document.hidden=true;p.emit('visibilitychange',true);
 p.document.hidden=false;p.emit('visibilitychange',true);
 p.emit('blur');p.emit('focus');
 assert.deepEqual(calls,['hidden','visible','hidden','visible']);
});

function pausedPage(){
 const p=page(),calls=[];
 p.bridge.connectGame(type=>{
  calls.push(type);
  if(type==='resume')p.bridge.update({mode:'',started:true,finished:false});
  if(type==='unlock' || type==='hidden')p.bridge.update({mode:'pause',started:true,finished:false});
 });
 p.bridge.update({mode:'pause',started:true,finished:false});
 return {p,calls};
}
test('one pause-menu click requests lock once and resumes only after confirmation',()=>{
 const {p,calls}=pausedPage();let requests=0;
 p.node('canvas').requestPointerLock=()=>{requests++;};
 assert.equal(p.node('pause-resume').hidden,false);
 p.node('pause-resume').onclick();
 p.node('pause-resume').onclick();
 assert.equal(requests,1);assert.deepEqual(calls,[]);
 assert.equal(p.node('pause-resume').disabled,true);
 p.document.pointerLockElement=p.node('canvas');p.emit('pointerlockchange',true);
 assert.deepEqual(calls,['lock','resume']);
 assert.equal(p.node('pause-resume').hidden,true);assert.equal(p.node('recapture').hidden,true);
});
test('twenty Escape/unlock/resume cycles do not accumulate extra clicks',()=>{
 const {p,calls}=pausedPage();let requests=0;
 p.node('canvas').requestPointerLock=()=>{requests++;};
 for(let i=0;i<20;i++){
  p.document.pointerLockElement=null;p.emit('pointerlockchange',true);
  p.node('pause-resume').onclick();
  p.document.pointerLockElement=p.node('canvas');p.emit('pointerlockchange',true);
  assert.equal(calls.filter(x=>x==='resume').length,i+1);
 }
 assert.equal(requests,20);
});
test('rejected promise keeps pause, shows feedback, and permits a single retry',async()=>{
 const {p,calls}=pausedPage();
 p.node('canvas').requestPointerLock=()=>Promise.reject(new Error('denied'));
 p.node('pause-resume').onclick();await Promise.resolve();
 assert.deepEqual(calls,[]);assert.equal(p.node('pause-resume').disabled,false);
 assert.equal(p.node('lock-status').hidden,false);
 p.node('canvas').requestPointerLock=()=>undefined;p.node('pause-resume').onclick();
 p.document.pointerLockElement=p.node('canvas');p.emit('pointerlockchange',true);
 assert.deepEqual(calls,['lock','resume']);assert.equal(p.node('lock-status').hidden,true);
});
test('legacy pointerlockerror and synchronous errors recover without resuming',()=>{
 const {p,calls}=pausedPage();
 p.node('canvas').requestPointerLock=()=>undefined;p.node('pause-resume').onclick();
 p.emit('pointerlockerror',true);
 assert.equal(p.node('pause-resume').disabled,false);assert.deepEqual(calls,[]);
 p.node('canvas').requestPointerLock=()=>{throw new Error('blocked');};p.node('pause-resume').onclick();
 assert.equal(p.node('pause-resume').disabled,false);assert.deepEqual(calls,[]);
});
test('blur or navigation while lock is pending cancels a late resume',()=>{
 for(const interrupt of ['blur','settings']){
  const {p,calls}=pausedPage();let releases=0;
  p.document.exitPointerLock=()=>{releases++;p.document.pointerLockElement=null;};
  p.node('canvas').requestPointerLock=()=>undefined;p.node('pause-resume').onclick();
  if(interrupt==='blur')p.emit('blur');else p.bridge.update({mode:'settings',started:true});
  p.document.pointerLockElement=p.node('canvas');p.emit('pointerlockchange',true);
  assert.equal(releases,1);assert.equal(calls.includes('resume'),false);assert.equal(calls.includes('lock'),false);
 }
});
test('another element lock cannot resume the game and canvas recapture has no eager resume',()=>{
 const {p,calls}=pausedPage();
 p.node('canvas').requestPointerLock=()=>undefined;p.node('pause-resume').onclick();
 p.document.pointerLockElement=p.node('manual');p.emit('pointerlockchange',true);
 assert.equal(calls.includes('resume'),false);
 p.document.pointerLockElement=null;p.bridge.update({mode:'',started:true});
 p.node('recapture').onclick();assert.equal(calls.includes('lock'),false);
 p.document.pointerLockElement=p.node('canvas');p.emit('pointerlockchange',true);
 assert.equal(calls.at(-1),'lock');assert.equal(calls.includes('resume'),false);
});
test('pause resume control follows 16:9 letterboxing at small and ultrawide sizes',()=>{
 const {p}=pausedPage();
 assert.equal(p.node('pause-resume').style.left,'710px');
 assert.equal(p.node('pause-resume').style.top,'350px');
 p.resize(1280,720);
 assert.ok(Math.abs(parseFloat(p.node('pause-resume').style.left)-473.3333)<.001);
 assert.ok(Math.abs(parseFloat(p.node('pause-resume').style.top)-233.3333)<.001);
 p.resize(2560,1080);assert.equal(p.node('pause-resume').style.left,'1030px');
 p.resize(800,600);assert.ok(Math.abs(parseFloat(p.node('pause-resume').style.top)-220.8333)<.001);
});
test('automated QA never requests user pointer capture or shows resume control',()=>{
 const p=page({query:'?qa=integration'});let requests=0;
 p.node('canvas').requestPointerLock=()=>{requests++;};
 p.bridge.update({mode:'pause',started:true});p.node('pause-resume').onclick();
 assert.equal(p.node('pause-resume').hidden,true);assert.equal(requests,0);
});
