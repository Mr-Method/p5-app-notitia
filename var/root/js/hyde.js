// Perl Artistic license except where stated otherwise

var Behaviour = new Class( {
   Implements: [ Events, Options ],

   config      : {
      inputs   : {},
      sidebars : {},
      server   : {},
      slider   : {},
      submit   : {},
      togglers : {},
      window   : {}
   },

   options          : {
      baseURL       : null,
      cookieDomain  : '',
      cookiePath    : '/',
      cookiePrefix  : 'behaviour',
      editing       : false,
      firstField    : null,
      formName      : null,
      keyMap        : 'default',
      message       : null,
      messages      : [],
      target        : null,
      useCodeMirror : false
   },

   initialize: function( options ) {
      this.setOptions( options ); this.collection = [];

      Locale.use( 'en-GB' ); this.resize(); this.attach();
   },

   attach: function() { // Add the event handling
      var opt = this.options;

      window.addEvent( 'load', function() {
         this.load( opt.firstField ) }.bind( this ) );

      this.resizer = new Debouncer( this.resize );

      window.addEvent( 'resize', this.resizer.handleEvent.bind( this.resizer ));
   },

   collect: function( object ) {
      this.collection.include( object ); return object;
   },

   load: function( first_field ) {
      var el, opt = this.options;

      if (opt.editing && opt.useCodeMirror) {
         this.editor    = new Editor( {
            codeMirror  : { keyMap: opt.keyMap },
            element     : $( 'markdown-editor' ) } );
         this.editor.render();
      }

      this.cookies      = new Cookies( {
         domain         : opt.cookieDomain,
         path           : opt.cookiePath,
         prefix         : opt.cookiePrefix } );

      this.restoreStateFromCookie();

      this.window       = new WindowUtils( {
         context        : this,
         target         : opt.target,
         url            : opt.baseURL } );
      this.submit       = new SubmitUtils( {
         context        : this,
         formName       : opt.formName } );
      this.dropmenu     = new DropMenu( { context: this } );
      this.headroom     = new Headroom( {
         context        : this,
         offset         : 108,
         tolerance      : 10 } );
      this.navigation   = new Navigation( { context: this } );
      this.noticeBoard  = new NoticeBoard( { context: this } );
      this.pickers      = new Pickers( { context: this } );
      this.replacements = new Replacements( { context: this } );
      this.sliders      = new Sliders( { context: this } );
      this.server       = new ServerUtils( {
         context        : this,
         url            : opt.baseURL } );
      this.togglers     = new Togglers( { context: this } );
      this.tips         = new Tips( {
         context        : this,
         fsWidthRatio   : 1.5,
         minWidth       : 200,
         onHide         : function() { this.fx.start( 0 ) },
         onInitialize   : function() {
            this.fx     = new Fx.Tween( this.tip, {
               duration : 500,
               link     : 'chain',
               onChainComplete: function() {
                  if (this.tip.getStyle( 'opacity' ) == 0)
                      this.tip.setStyle( 'visibility', 'hidden' );
               }.bind( this ),
               property : 'opacity' } ).set( 0 ); },
         onShow         : function() {
            this.tip.setStyle( 'visibility', 'visible' ); this.fx.start( 1 ) },
         showDelay      : 666 } );

      opt.messages.each( function( message ) {
         this.noticeBoard.create( message ) }.bind( this ) );

      if (first_field && (el = $( first_field ))) el.focus();
   },

   rebuild: function() {
      this.collection.each( function( object ) { object.build() } );
   },

   resize: function() {
      var footer, nav, ribbon = $( 'github-ribbon' ), w = window.getWidth();

      if (w >= 820) {
         if (ribbon) ribbon.setStyle( 'right', '16px' );

         if (nav = $( 'sub-nav-collapse' )) nav.removeProperty( 'style' );
      }
      else {
         if (ribbon) ribbon.setStyle( 'right', '0px' );
      }
   },

   restoreStateFromCookie: function() {
      /* Use state cookie to restore the visual state of the page */
      var cookie_str; if (! (cookie_str = this.cookies.get())) return;

      var cookies = cookie_str.split( '+' ), el;

      for (var i = 0, cl = cookies.length; i < cl; i++) {
         if (! cookies[ i ]) continue;

         var pair = cookies[ i ].split( '~' );
         var p0   = unescape( pair[ 0 ] ), p1 = unescape( pair[ 1 ] );

         /* Restore the state of any elements whose ids end in Disp */
         if (el = $( p0 + 'Disp' )) { p1 != 'false' ? el.show() : el.hide(); }
         /* Restore the className for elements whose ids end in Icon */
         if (el = $( p0 + 'Icon' )) {
            if (p1 != 'false') {
               el.addClass( 'true' ); el.removeClass( 'false' );
            }
            else {
               el.removeClass( 'true' ); el.addClass( 'false' );
            }
         }
         /* Restore the source URL for elements whose ids end in Img */
         if (el = $( p0 + 'Img'  )) { if (p1) el.src = p1; }
      }
   }
} );
