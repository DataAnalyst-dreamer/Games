// Read-only mock-DOM checks. This is not a real browser rendering test.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const htmlPath = path.resolve(process.argv[2]);
const html = fs.readFileSync(htmlPath, 'utf8');
const source = html.match(/<script>([\s\S]*?)<\/script>/)[1];
const nodes = new Map();
const document = {getElementById(id){if(!nodes.has(id))nodes.set(id,{value:id==='speed'?'1':'0',disabled:false});return nodes.get(id)}};
let callback;
let loads = 0;
class MockImage {
  set src(relative){
    const file = path.resolve(path.dirname(htmlPath), relative);
    assert.ok(file.startsWith(path.dirname(htmlPath)+path.sep));
    const bytes = fs.readFileSync(file);
    assert.equal(bytes.readUInt32BE(16),1920);
    assert.equal(bytes.readUInt32BE(20),1080);
    loads++;
    queueMicrotask(()=>this.onload());
  }
}
const context = vm.createContext({document,Image:MockImage,Promise,Error,requestAnimationFrame(fn){callback=fn}});
vm.runInContext(source,context);
assert.equal(document.getElementById('play').disabled,true);
setImmediate(()=>{
  try{
    assert.equal(loads,36);
    assert.equal(document.getElementById('play').disabled,false);
    assert.ok(callback);
    callback(100);
    for(let i=1;i<=20;i++)callback(100+i*1000/60);
    const index=vm.runInContext('index',context);
    assert.ok(index>=19&&index<=20,`time carry index=${index}`);
    document.getElementById('seek').value='7';
    document.getElementById('seek').oninput();
    assert.equal(vm.runInContext('index',context),7);
    assert.equal(vm.runInContext('playing',context),false);
    document.getElementById('restart').onclick();
    assert.equal(vm.runInContext('index',context),0);
    document.getElementById('speed').value='0.25';
    assert.ok(Math.abs(vm.runInContext('durationAt(0)',context)-1000/15)<0.001);
    console.log('PREVIEW_MOCK PASS=8 FAIL=0 (preload gating, 36 native FHD inputs, ready, RAF, elapsed carry, seek/pause, restart, 0.25 speed)');
  }catch(error){console.error(error);process.exitCode=1;}
});
