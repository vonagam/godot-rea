extends rea.Component

const ComponentScene := preload( 'Component.tscn' )


func render( arg: rea.Arg ) -> rea.NodeDescriptor:
  return ( rea.node( self )
    .children( [
      ( rea.scene( ComponentScene )
        .rendered()
        .prop( &'color', Color( 0.5, 0.5, 0.0 ) )
      ),
    ] )
  )
