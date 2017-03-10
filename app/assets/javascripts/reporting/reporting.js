//= require jquery-tablesorter

(function($){
  $(document).ajaxComplete(function() {
    // Override the default texts to enable translations
    $.tablesorter.language = {
          sortAsc      : I18n.t('js.sort.sorted_asc'),
          sortDesc     : I18n.t('js.sort.sorted_dsc'),
          sortNone     : I18n.t('js.sort.sorted_no'),
          sortDisabled : I18n.t('js.sort.sorting_disabled'),
          nextAsc      : I18n.t('js.sort.activate_asc'),
          nextDesc     : I18n.t('js.sort.activate_dsc'),
          nextNone     : I18n.t('js.sort.activate_no')
    };
    $('#sortable-table').not('.tablesorter').tablesorter();
  });
})(jQuery);
