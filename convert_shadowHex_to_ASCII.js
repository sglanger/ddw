function convert_shadowHex_to_ASCII(str) {
////////////////////////////////////////////////////
// Purpose: take in a shadow group in Hex, return ASCII string
// Caller: DICOM parser channel
//
/////////////////////////////////////////////////
	var func = 'convert_shadowHex_to_ASCII: ';
	var substr, str2="", buf="";
	logger.info ("entering convert \n" + str);

	while (str.length > 3) {
	  substr  = "0x" + str.slice(0, str.indexOf('\\')) ;
	  str2 = String.fromCharCode(substr);
	  buf = buf + str2 ;
	  str = str.substring(str.indexOf('\\')+ 1); 
	}
	//t_logError ("exiting convert \n" + buf);
	return buf;
}