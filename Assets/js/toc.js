(function(){
  // Build a simple Table of Contents for article pages.
  function slugify(text){
    return text.toString().toLowerCase().trim()
      .replace(/\s+/g,'-')
      .replace(/[^a-z0-9\-]/g,'')
      .replace(/-+/g,'-');
  }

  function ensureId(el){
    if(!el.id || el.id === ''){
      var base = slugify(el.textContent || el.innerText || 'section');
      var id = base;
      var i = 1;
      while(document.getElementById(id)){
        id = base + '-' + (i++);
      }
      el.id = id;
    }
    return el.id;
  }

  function buildTOC(containerSelector, headingsSelector){
    var toc = document.getElementById('auto-toc');
    if(!toc) return;
    toc.innerHTML = '';

    var article = document.querySelector('article');
    if(!article) article = document.body;

    // Select h2 and h3 within the article for TOC
    var headings = article.querySelectorAll(headingsSelector || 'h2, h3');
    if(!headings || headings.length === 0){
      toc.innerHTML = '<li class="toc-empty">No sections found.</li>';
      return;
    }

    headings.forEach(function(h){
      var id = ensureId(h);
      var li = document.createElement('li');
      li.className = 'toc-item toc-' + h.tagName.toLowerCase();
      var a = document.createElement('a');
      a.href = '#' + id;
      a.textContent = (h.textContent || h.innerText).trim();
      a.addEventListener('click', function(){
        // close any mobile sidebars if necessary — no-op here
      });
      li.appendChild(a);
      toc.appendChild(li);
    });
  }

  function readingProgress(){
    var progressEl = document.getElementById('readingProgress');
    var article = document.querySelector('article');
    if(!progressEl || !article) return;
    var rect = article.getBoundingClientRect();
    var scrollTop = window.scrollY || window.pageYOffset;
    var articleTop = scrollTop + rect.top;
    var articleHeight = article.offsetHeight;
    var viewHeight = window.innerHeight;
    var scrollPos = (scrollTop - articleTop + viewHeight/2) / articleHeight;
    var pct = Math.max(0, Math.min(1, scrollPos));
    progressEl.style.width = (pct*100) + '%';
  }

  function highlightOnScroll(){
    var toc = document.getElementById('auto-toc');
    if(!toc) return;
    var links = toc.querySelectorAll('a');
    if(!links || links.length === 0) return;
    var headings = Array.from(links).map(function(a){
      return document.getElementById(a.getAttribute('href').slice(1));
    });

    var currentIndex = -1;
    var topOffsets = headings.map(function(h){ return h ? h.getBoundingClientRect().top + window.scrollY : Infinity; });

    function update(){
      var scroll = window.scrollY || window.pageYOffset;
      var mid = scroll + window.innerHeight/3; // arbitrary
      for(var i=0;i<topOffsets.length;i++){
        if(mid >= topOffsets[i]) currentIndex = i;
      }
      // clear
      links.forEach(function(a){ a.classList.remove('active'); });
      if(currentIndex >= 0 && links[currentIndex]){
        links[currentIndex].classList.add('active');
      }
    }

    window.addEventListener('scroll', function(){
      // debounce lightly
      if(window._toc_scroll_timeout) clearTimeout(window._toc_scroll_timeout);
      window._toc_scroll_timeout = setTimeout(function(){
        readingProgress();
        update();
      }, 50);
    }, {passive:true});

    // initial
    readingProgress();
    update();
  }

  function init(){
    buildTOC('#auto-toc', 'h2, h3');
    highlightOnScroll();
  }

  if(document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init); else init();
})();
