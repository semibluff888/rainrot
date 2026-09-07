// Exercises shipped shell event handling with a minimal DOM, without a browser driver.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const source=fs.readFileSync(require('node:path').join(__dirname,'../site/shell.js'),'utf8');

function page({width=1920,height=1080,dpr=1,query=''}={}){
 const elements=new Map(),events={},docEvents={};let frame,observer,media,config;
 const stageRect={width,height};
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
