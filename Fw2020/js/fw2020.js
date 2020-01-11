// J2 FW2020 theme.
//
// Distributed under the MIT license
// https://github.com/johnfairh/J2/blob/master/LICENSE
//

/* global $ Prism anchors lunr */

'use strict'

const $body = $('body')

// Figure out Dash mode early on so we can avoid
// running lots of code.  All of the style stuff happens
// through CSS dependent on our setting the 'dash' class.
//
// Refactor all this when we move the Prism lexer
// customizations upstream or to a separate file.
//
const isDashMode =
  new URLSearchParams(window.location.search).has('dash') ||
  typeof window.dash !== 'undefined'

if (isDashMode) {
  $('html').addClass('dash')
}

/*
 * Prism customization for CSS tag names.
 */
Prism.plugins.customClass.map((className, language) => {
  return 'pr-' + className
})

/*
 * Prism customization for autoloading missing languages.
 */
Prism.plugins.autoloader.languages_path = 'https://cdnjs.cloudflare.com/ajax/libs/prism/1.17.1/components/'

//
// Narrow-mode nav collapse
//
const navControl = {
  setup () {
  },

  ready () {
    const $nav = $('#nav-column')
    const $navToggle = $('#nav-toggle-button')

    $navToggle.click(() => {
      $nav.toggleClass('d-none')
      $navToggle.attr('aria-expanded', !$nav.hasClass('d-none'))
      return false
    })
  }
}

//
// Language-switching controls
//
const langControl = {

  // Sync body style from URL for initial layout
  setup () {
    const params = new URLSearchParams(window.location.search)
    for (const lang of ['swift', 'objc']) {
      if (params.has(lang)) {
        $body.removeClass('j2-swift j2-objc')
        $body.addClass(`j2-${lang}`)
        break
      }
    }
  },

  // Initial chrome and event handlers when ready
  ready () {
    this.langMenu = $('#language-menu')
    this.langSwift = $('#language-menu-swift')
    this.langObjC = $('#language-menu-objc')

    this.updateChrome()

    this.langSwift.click(() => this.menuItemClicked('j2-swift'))
    this.langObjC.click(() => this.menuItemClicked('j2-objc'))

    $('#action-language').click(() => { this.toggle(); return false })
  },

  // Sync chrome from body
  updateChrome () {
    const doUpdate = (langName, fromEl, toEl) => {
      this.langMenu.text(langName)
      fromEl.attr('aria-current', false)
      toEl.attr('aria-current', true)
      return langName.toLowerCase()
    }

    if ($body.hasClass('j2-swift')) {
      return doUpdate('Swift', this.langObjC, this.langSwift)
    } else {
      return doUpdate('ObjC', this.langSwift, this.langObjC)
    }
  },

  // Update for a menu click
  menuItemClicked (className) {
    this.langMenu.dropdown('toggle')
    if (!$body.hasClass(className)) {
      this.toggle()
    }
    return false
  },

  // Flip current on keypress/click
  toggle () {
    $body.toggleClass('j2-swift j2-objc')
    const lang = this.updateChrome()
    const currentHash = window.location.hash
    window.history.replaceState({}, document.title, '?' + lang + currentHash)
  }
}

//
// Collapse management
//
const collapseControl = {
  // State of global collapse
  allCollapsed: false,
  // Distinguish user-uncollapse from global
  toggling: false,
  // Span for 'collapse' & 'expand' UI
  $actionCollapseSpan: null,
  $actionExpandSpan: null,

  setup () {
    // When we follow a link to the title of a collapsed item,
    // uncollapse it.
    $(window).on('hashchange', () => this.ensureUncollapsed())
  },

  // Helper to uncollapse at the current anchor
  ensureUncollapsed () {
    const $el = $(window.location.hash)
    if ($el.hasClass('j2-item-anchor')) {
      const $collapse = $('#_' + $el.attr('id'))
      $collapse.collapse('show')
    }
  },

  updateChrome () {
    if (this.allCollapsed) {
      this.actionCollapseSpan.addClass('d-none')
      this.actionExpandSpan.removeClass('d-none')
    } else {
      this.actionCollapseSpan.removeClass('d-none')
      this.actionExpandSpan.addClass('d-none')
    }
  },

  ready () {
    // Default collapse toggle state (from a body style?)
    this.allCollapsed = $('.collapse.show').length === 0

    this.actionCollapseSpan = $('#action-collapse-collapse')
    this.actionExpandSpan = $('#action-collapse-expand')
    this.updateChrome()

    // If the browser URL has an item's hash, but the user
    // collapses that item and then follows a link to that _same_
    // item, then poke it so we uncollapse it again (there's no
    // `hashchange` event here)
    $("a:not('.j2-item-title')").click((e) => {
      if (window.location.href === e.target.href) {
        this.ensureUncollapsed()
      }
    })

    // When a collapsed item opens, update the browser URL
    // to point at the item's title _without_ creating a
    // new history entry.
    $('.j2-item-popopen-wrapper').on('show.bs.collapse', (e) => {
      if (this.toggling) return
      const title = $(e.target).attr('id')
      window.history.replaceState({}, document.title, '#' + title.substr(1))
    })

    $('#action-collapse').click(() => { this.toggle(); return false })

    // If we loaded the page with a link to a collapse anchor, uncollapse it.
    this.ensureUncollapsed()
  },

  readyDashMode () {
    $('.j2-item-title, .j2-item-title-discouraged').removeAttr('data-toggle')
  },

  // Collapse/Uncollapse all on keypress/link
  toggle () {
    this.toggling = true
    if (this.allCollapsed) {
      $('.collapse').collapse('show')
    } else {
      $('.collapse').collapse('hide')
    }
    this.toggling = false
    this.allCollapsed = !this.allCollapsed
    this.updateChrome()
  }
}

//
// Search - load json, index with lunr, UI with typeahead.
//
const searchControl = {
  // relative path to docroot
  rootPath: '',
  // translated messages
  loadingMessage: null,
  failedMessage: null,
  notFoundMessage: null,
  // state of json search data
  jsonFetchFailed: false,
  searchData: null,
  // lunr index object
  lunrIndex: null,

  // HTML generation

  dropdownHtml (suggestion, secondary, el) {
    return `<div class="tt-droprow">\
            <${el} class="tt-sug-name">${suggestion}</${el}>\
            <${el} class="tt-sug-parent-name">${secondary}</${el}>\
            </div>`
  },

  suggestionHtml (result, element) {
    return this.dropdownHtml(result.name, result.parent_name || '', element)
  },

  notFoundTemplate () {
    const msg = this.jsonFetchFailed ? this.failedMessage
      : (this.searchData ? this.notFoundMessage : this.loadingMessage)
    return this.dropdownHtml(`<i>${msg || 'Not found'}</i>`, '', 'span')
  },

  // Start Lunr setup asap
  setup () {
    this.rootPath = $body.data('root-path')

    $.getJSON(this.rootPath + '/search.json').then((searchData) => {
      this.searchData = searchData

      // setting this enables search
      this.lunrIndex = lunr((builder) => {
        builder.ref('url')
        builder.field('name')
        builder.field('abstract')
        for (const [url, doc] of Object.entries(searchData)) {
          builder.add({ url: url, name: doc.name, abstract: doc.abstract })
        }
      })
    }, () => {
      this.jsonFetchFailed = true
    })
  },

  // Do a search when prompted by typeahead.
  search (query, sync) {
    if (this.lunrIndex === null) {
      // Bail if lunr is not ready yet
      return
    }

    const lcSearch = query.toLowerCase()
    const results = this.lunrIndex.query((q) => {
      q.term(lcSearch, { boost: 100 })
      q.term(lcSearch, {
        boost: 10,
        wildcard: lunr.Query.wildcard.TRAILING
      })
    }).map((result) => {
      const doc = this.searchData[result.ref]
      doc.url = result.ref
      return doc
    })

    sync(results)
  },

  // Configure typeahead when dom ready
  ready () {
    // Load text
    this.loadingMessage = $('#text-loading').text()
    this.failedMessage = $('#text-failed').text()
    this.notFoundMessage = $('#text-notfound').text()

    const $typeaheads = $('input')

    $typeaheads.each((_, entry) => {
      const searchEntryFormat = entry.dataset.searchFormat

      $(entry).typeahead({
        highlight: true,
        minLength: 1,
        autoselect: true
      },
      {
        limit: 10,
        displayKey: 'name',
        templates: {
          suggestion: (r) => this.suggestionHtml(r, searchEntryFormat),
          notFound: this.notFoundTemplate.bind(this)
        },
        source: this.search.bind(this)
      })
    })

    $typeaheads.on('typeahead:select', (e, result) => {
      window.location = this.rootPath + '/' + result.url
    })

    // Searchbar action in aux nav
    $('#action-search').click(() => {
      $('input:visible').focus()
      return false
    })
  }
}

//
// Keypress handler
//
const keysControl = {
  setup () {
    $(document).keydown((e) => this.keydown(e))
  },

  keydown (e) {
    const $searchField = $('input:visible')

    if ($searchField.is(':focus')) {
      if (e.key === 'Escape') {
        $searchField.blur()
        $searchField.typeahead('val', '')
      }
    } else {
      switch (e.key) {
        case '/': $searchField.focus(); return false
        case 'a': collapseControl.toggle(); break
        case 'l': langControl.toggle(); break
        case 'd': $('#size-debug').toggleClass('d-flex d-none'); break
      }
    }
  }
}

if (!isDashMode) {
  navControl.setup()
  langControl.setup()
  collapseControl.setup()
  searchControl.setup()
  keysControl.setup()
}

$(function () {
  if (isDashMode) {
    collapseControl.readyDashMode()
    return
  }

  // Narrow size nav toggle
  navControl.ready()

  // Auto-add anchors to headings
  anchors.options.visible = 'touch'
  anchors.add('.j2-anchor span')

  // Sync content mode from URL
  langControl.ready()

  // Initialise collapse-anchor link
  collapseControl.ready()

  // Typeahead
  searchControl.ready()
})
