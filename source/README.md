# tcl-lib
die lib muss lib<Name> heißen, z. B.

     libTools.so
     libTools.dylib
     
die Funktionen im C-sourcefile müssen entsprechend

    int DLLEXPORT <Name>_Init
 
 also
 
     int DLLEXPORT Tools_Init ( ...
     
 wobei der 1. Buchstabe groß, die weiteren klein geschrieben werden, dies ist wichtig!
 
 
  