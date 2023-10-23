- quantize_service.dart is the 'root' file, it is the only one you should edit.
- run `dart run build_runner build` to get the other ones generated
- After that, run `dart compile js quantize_service.web.g.dart  -o quantize_service.web.g.dart.js` in this directory.
- An app embedding the library will need to place the generated js files in the exact same folder structure as here.
i.e. see the `example` folder, and note there is a `lib/extract/service` folder with the generated JS files copied in.