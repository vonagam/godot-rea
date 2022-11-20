extends rea.Component


func render( arg: rea.Arg ) -> rea.NodeDescriptor:
  var blue_state := rea.use.state( 0.0 )

  var on_input := rea.use.callback( func ( input: InputEvent ) -> void:
    blue_state.update( func ( value: float ) -> float: return value * 0.5 + randf() * 0.5 )
  )

  var ref_update := rea.use.callback( func ( control: Control ) -> void:
    if control != null:
      control.set_anchors_and_offsets_preset( Control.PRESET_FULL_RECT )
  )

  return ( rea.node( self )
    .children( [
      ( rea.type( ColorRect )
        .ref( ref_update )
        .bind( &'gui_input', on_input )
        .prop( &'color', Color( 0.25, 0.75, blue_state.value ) )
        .children( [
          ( rea.type( Label )
            .ref( ref_update )
            .prop( &'horizontal_alignment', HORIZONTAL_ALIGNMENT_CENTER )
            .prop( &'vertical_alignment', VERTICAL_ALIGNMENT_CENTER )
            .prop( &'text', 'State: %f' % blue_state.value )
          ),
        ] )
      ),
    ] )
  )
