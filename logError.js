function logError (str) {
////////////////////////////////////
// Purpose: Central output for debug messaging
//		Use this version for Prod Log
// Caller: throughout this code
/////////////////////////////////////
	str = str + "\n" ;
   	FileUtil.write('/media/dbase/error_images/log.rtf', true, str);
	return ;
}