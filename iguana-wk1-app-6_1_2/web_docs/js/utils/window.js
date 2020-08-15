/** @license
 * Copyright (c) 2010-2011 iNTERFACEWARE Inc.  All rights reserved.
 */

// Browser Window Javascript

function WINgetWindowWidth() {
   if (window.innerWidth === undefined) {
      return document.documentElement.clientWidth;
   }
   else {
      return window.innerWidth;
   }
}

function WINgetWindowHeight() {
   if (window.innerHeight === undefined) {
      return document.documentElement.clientHeight;
   }
   else {
      return window.innerHeight;
   }
}

function WINgetWindowLeft() {
   var ScrollLeft = document.body.scrollLeft;

   if (0 == ScrollLeft) {
      if (window.pageXOffset) {
         ScrollLeft = window.pageXOffset;
      }
      else {
         ScrollLeft = (document.body.parentElement) ? document.body.parentElement.scrollLeft : 0;
      }
   }

   return ScrollLeft;
}

function WINgetWindowTop() {
   var ScrollTop = document.body.scrollTop;

   if (0 == ScrollTop) {
      if (window.pageYOffset) {
         ScrollTop = window.pageYOffset;
      }
      else {
         ScrollTop = (document.body.parentElement) ? document.body.parentElement.scrollTop : 0;
      }
   }

   return ScrollTop;
}

// Gets the offsetTop of an element relative to the entire browser window.
function WINwindowOffsetTop(Element) {
   var Top = 0;

   for (var Parent = Element; Parent != null; Parent = Parent.offsetParent) {
      if (Parent.offsetTop !== undefined) {
         Top += Parent.offsetTop;
      }
   }

   for (var Parent = Element.parentNode; Parent != null; Parent = Parent.parentNode) {
      if (Parent.scrollTop !== undefined) {
         Top -= Parent.scrollTop;
      }
   }

   return Top;
}

// Gets the offsetLeft of an element relative to the entire browser window.
function WINwindowOffsetLeft(Element) {
   var Left = 0;

   for (var Parent = Element; Parent != null; Parent = Parent.offsetParent) {
      if (Parent.offsetLeft !== undefined) {
         Left += Parent.offsetLeft;
      }
   }

   for (var Parent = Element.parentNode; Parent != null; Parent = Parent.parentNode) {
      if (Parent.scrollLeft !== undefined) {
         Left -= Parent.scrollLeft;
      }
   }

   return Left;
}

function WINgetStyle(Element, StyleName) {
   var StyleValue = Element.style[StyleName];

   if (!StyleValue) {
      if (window.getComputedStyle) {
         var css = document.defaultView.getComputedStyle(Element, null);
         StyleValue = css ? css[StyleName] : null;
      }
      else if (Element.currentStyle) {
         StyleValue = Element.currentStyle[StyleName];
      }
   }

   return StyleValue;
}
