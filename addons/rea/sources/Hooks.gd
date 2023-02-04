# Common

const Render := preload( 'Internal.gd' ).Render
const ContextElement := preload( 'Internal.gd' ).ContextElement

class Utils:
  static func push_data( render: Render, data_index: int, value: Variant ) -> void:
    if data_index == 0: render.data = []
    render.data.push_back( value )

  static func push_cleanup( render: Render, cleanup: Callable ) -> void:
    if render.cleanups.is_empty(): render.cleanups = []
    render.cleanups.push_back( cleanup )


# State

class StateInternals:
  var render: Render
  var data_index: int


# Effect

class Effect:
  var cleanup: Callable
  var deps: Array[ Variant ] = REA.EMPTY_ARRAY

  func update( update: Callable, deps: Array ) -> void:
    if ! is_same( self.deps, deps ): return
    var prev_cleanup := self.cleanup
    if prev_cleanup.is_valid(): prev_cleanup.call()
    var next_cleanup: Variant = update.call()
    self.cleanup = next_cleanup if next_cleanup is Callable else REA.NOOP

  func clean() -> void:
    if self.cleanup.is_valid(): self.cleanup.call_deferred()


# Context

class Contexted:
  var context: GDScript
  var element: ContextElement
  var fallback: Variant


# Reducer

class ReducerInternals:
  var render: Render
  var data_index: int
  var reducer: Callable


# Memo

class Memo:
  var value: Variant
  var deps: Array[ Variant ] = REA.EMPTY_ARRAY


# Public

class use:

  # State

  class State:
    var value: Variant:
      get: return _rea_value

    var _rea_internals: Variant
    var _rea_value: Variant

    func update( next_value: Variant ) -> void:
      var internals: StateInternals = self._rea_internals
      var render := internals.render
      var prev_state: State = render.data[ internals.data_index ]
      var prev_value: Variant = prev_state._rea_value
      if next_value is Callable: next_value = next_value.call( prev_value )
      if is_same( next_value, prev_value ): return
      var next_state := State.new()
      next_state._rea_internals = internals
      next_state._rea_value = next_value
      render.data[ internals.data_index ] = next_state
      render.rerender_deferred()

  static func state( initial_value: Variant ) -> State:
    var render := REA.render
    var is_mounted := REA.render_is_mounted
    var data_index := REA.render_data_index + 1
    REA.render_data_index = data_index

    if is_mounted:
      var state: State = render.data[ data_index ]
      return state

    var internals := StateInternals.new()
    internals.render = render
    internals.data_index = data_index

    var state := State.new()
    state._rea_internals = internals
    state._rea_value = initial_value.call() if initial_value is Callable else initial_value
    Utils.push_data( render, data_index, state )

    return state


  # Effect

  static func effect( update: Callable, deps := REA.EMPTY_ARRAY ) -> void:
    var render := REA.render
    var is_mounted := REA.render_is_mounted
    var data_index := REA.render_data_index + 1
    REA.render_data_index = data_index

    if is_mounted:
      var effect: Effect = render.data[ data_index ]
      if deps != effect.deps:
        effect.deps = deps
        effect.update.call_deferred( update, deps )
      return

    var effect := Effect.new()
    effect.deps = deps
    effect.update.call_deferred( update, deps )
    Utils.push_data( render, data_index, effect )
    Utils.push_cleanup( render, effect.clean )


  # Context

  static func context( context: GDScript ) -> Variant:
    var render := REA.render
    var is_mounted := REA.render_is_mounted
    var data_index := REA.render_data_index + 1
    REA.render_data_index = data_index

    if is_mounted:
      var contexted: Contexted = render.data[ data_index ]
      assert( contexted.context == context )
      var element := contexted.element
      return element.context_value if element != null else contexted.fallback

    var element: ContextElement = render.element.contexts.get( context )
    if element != null:
      element.context_users.push_back( render )
      Utils.push_cleanup( render, func () -> void: element.context_users.erase( render ) )

    var contexted := Contexted.new()
    contexted.context = context
    contexted.element = element
    contexted.fallback = context.get_fallback() if element == null else null
    Utils.push_data( render, data_index, contexted )

    return element.context_value if element != null else contexted.fallback


  # Reducer

  class Reducer:
    var value: Variant:
      get: return _rea_value

    var _rea_internals: Variant
    var _rea_value: Variant

    func update( action: Variant ) -> void:
      var internals: ReducerInternals = self._rea_internals
      var render := internals.render
      var prev_reducer: Reducer = render.data[ internals.data_index ]
      var prev_value: Variant = prev_reducer._rea_value
      var next_value: Variant = internals.reducer.call( prev_value, action )
      if is_same( next_value, prev_value ): return
      var next_reducer := Reducer.new()
      next_reducer._rea_internals = internals
      next_reducer._rea_value = next_value
      render.data[ internals.data_index ] = next_reducer
      render.rerender_deferred()

  static func reducer( reducer: Callable, initial_value: Variant, init: Callable = REA.NOOP ) -> Reducer:
    var render := REA.render
    var is_mounted := REA.render_is_mounted
    var data_index := REA.render_data_index + 1
    REA.render_data_index = data_index

    if is_mounted:
      var result: Reducer = render.data[ data_index ]
      return result

    var internals := ReducerInternals.new()
    internals.render = render
    internals.data_index = data_index
    internals.reducer = reducer

    var result := Reducer.new()
    result._rea_internals = internals
    result._rea_value = init.call( initial_value ) if init.is_valid() else initial_value
    Utils.push_data( render, data_index, result )

    return result


  # Callback

  static func callback( callback: Callable, deps := REA.EMPTY_ARRAY ) -> Callable:
    var render := REA.render
    var is_mounted := REA.render_is_mounted
    var data_index := REA.render_data_index + 1
    REA.render_data_index = data_index

    if is_mounted:
      var memo: Memo = render.data[ data_index ]
      if deps != memo.deps:
        memo.value = callback
        memo.deps = deps
      return memo.value

    var memo := Memo.new()
    memo.value = callback
    memo.deps = deps
    Utils.push_data( render, data_index, memo )

    return memo.value


  # Memo

  static func memo( producer: Callable, deps := REA.EMPTY_ARRAY ) -> Variant:
    var render := REA.render
    var is_mounted := REA.render_is_mounted
    var data_index := REA.render_data_index + 1
    REA.render_data_index = data_index

    if is_mounted:
      var memo: Memo = render.data[ data_index ]
      if deps != memo.deps:
        memo.value = producer.call()
        memo.deps = deps
      return memo.value

    var memo := Memo.new()
    memo.value = producer.call()
    memo.deps = deps
    Utils.push_data( render, data_index, memo )

    return memo.value


  # Ref

  class Ref:
    var current: Variant

    func update( current: Variant ) -> void:
      self.current = current

  static func ref( initial_value: Variant = null ) -> Ref:
    var render := REA.render
    var is_mounted := REA.render_is_mounted
    var data_index := REA.render_data_index + 1
    REA.render_data_index = data_index

    if is_mounted:
      var ref: Ref = render.data[ data_index ]
      return ref

    var ref := Ref.new()
    ref.current = initial_value
    Utils.push_data( render, data_index, ref )

    return ref
