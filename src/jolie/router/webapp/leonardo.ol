/*
   Copyright 2008-2014 Fabrizio Montesi <famontesi@gmail.com>

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

include "console.iol"
include "file.iol"
include "string_utils.iol"
include "protocols/http.iol"

include "public/interfaces/FrontendInterface.iol"

include "config.iol"
include "../dependencies.iol"

execution { concurrent }

interface HTTPInterface {
RequestResponse:
	default(DefaultOperationHttpRequest)(undefined)
}


outputPort Frontend {
	Interfaces: FrontendInterface
}

embedded {
	Jolie:
	"frontend.ol" in Frontend
}

inputPort HTTPInput {
Protocol: http {
	.keepAlive = false; // Keep connections open
	.debug = DebugHttp;
	.debug.showContent = DebugHttpContent;
	.format -> format;
	.contentType -> mime;
	.statusCode -> statusCode;

	.default = "default"
}
Location: Location_Leonardo
Interfaces: HTTPInterface
Aggregates: Frontend
}

init
{
	if ( is_defined( args[0] ) && args[0]=="single" ) {
		RESOURCE_COLLECTION_FOLDER = "../resource_collections/";
		documentRootDirectory = RootContentDirectory
	} else {
		RESOURCE_COLLECTION_FOLDER = "./resource_collections/";
		documentRootDirectory = "./webapp/www/"
	}
	;
	rep = JDEP_API_ROUTER;
	rep.regex = "socket://";
	rep.replacement = "";
	replaceAll@StringUtils( rep )( api_router_location );
	println@Console("Api Interfaces Web Application is running...")()
}

main
{
	[ default( request )( response ) {
		scope( s ) {
			install( FileNotFound => println@Console( "File not found: " + file.filename )(); statusCode = 404 );

			s = request.operation;
			s.regex = "\\?";
			split@StringUtils( s )( s );

			// Default page
      shouldAddIndex = false;
      if ( s.result[0] == "" ) {
              shouldAddIndex = true
      } else {
              e = s.result[0];
              e.suffix = "/";
              endsWith@StringUtils( e )( shouldAddIndex )
      };
      if ( shouldAddIndex ) {
              s.result[0] += DefaultPage
      };

			spl = s.result[0];
			spl.regex = "\\.";
			split@StringUtils( spl )( spl_res );

			json = false;
			if ( spl_res.result[1] == "json" ) {
				file.filename = RESOURCE_COLLECTION_FOLDER + s.result[0];
				json = true
			} else {
				file.filename = documentRootDirectory + s.result[0]
			};
			getMimeType@File( file.filename )( mime );

			mime.regex = "/";
			split@StringUtils( mime )( s );
			if ( s.result[0] == "text" ) {
				file.format = "text";
				format = "html"
			} else {
				file.format = format = "binary"
			};
			readFile@File( file )( response );
			if ( json ) {
					rep = string( response );
					rep.regex = "\"host\":\".*?\"";
					rep.replacement = "\"host\":\"" + api_router_location + "\"";
					replaceAll@StringUtils( rep )( response )
			}
		}
	} ] { nullProcess }
}
