extends rea.Component


func render( arg: rea.Arg ) -> rea.NodeDescriptor:
  var text := rea.use.state( '' )

  return ( rea.node( self )
    .portals( [
      ( rea.path( ^'input' )
        .prop( 'text', text.value )
        .bind( 'text_changed', text.update )
      ),
      ( rea.path( ^'label' )
        .prop( 'text', text.value )
      ),
    ] )
  )
