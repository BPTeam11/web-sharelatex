define [
	"base"
], (App) ->
	App.directive 'aDisabled', () ->
		return compile: (tElement, tAttrs, transclude) ->
      # disable ngClick
      if(tAttrs.ngClick?)
        tAttrs.ngClick = "!(#{tAttrs["aDisabled"]}) && (#{tAttrs["ngClick"]});"

      return (scope, iElement, iAttrs) ->
        # toggle disabled class
        scope.$watch iAttrs["aDisabled"], (newValue) ->
          if newValue?
            iElement.toggleClass "disabled", newValue

        # prevent opening link
        iElement.on "click", (e) ->
          if scope.$eval(iAttrs["aDisabled"])
            e.preventDefault()