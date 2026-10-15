(function(){
  function show(msg){
    try{
      document.title = 'ERR ' + msg;
      var d = document.getElementById('__err');
      if(!d){ d = document.createElement('div'); d.id='__err';
        d.style.cssText='position:fixed;left:0;right:0;bottom:0;background:#c00;color:#fff;font:13px/1.4 monospace;padding:8px 10px;z-index:9999999;white-space:pre-wrap';
        (document.body||document.documentElement).appendChild(d); }
      d.textContent = msg;
    }catch(_){}
  }
  window.addEventListener('error', function(e){
    show('JS ERROR: ' + e.message + '  @ ' + String(e.filename||'').split('/').pop() + ':' + e.lineno + ':' + e.colno);
  });
  window.addEventListener('unhandledrejection', function(e){ show('PROMISE: ' + (e.reason && e.reason.message || e.reason)); });
  window.addEventListener('load', function(){
    setTimeout(function(){
      if (typeof window.DEF === 'undefined' && typeof window.S === 'undefined' && typeof window.capPrompt === 'undefined'){
        show('App script did not finish - DEF/S/capPrompt all undefined (silent abort, no error event).');
      }
    }, 600);
  });
})();