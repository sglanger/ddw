function sendEmail(to, cc, title, content){
////////////////////////////////////
// Purpose: For Exceptions in Prod, this
//		emails ALerts to "to"
// Caller: Catch
//
// var smtpConn = SMTPConnectionFactory.createSMTPConnection();
// smtpConn.send('to', 'cc', 'from', 'subject', 'body');
/////////////////////////////////////
   var host = 'smtprelay.mayo.edu';
   var port = '25' , auth = false, secure = '', password = '';
   var username = 'dlradtrac@mayo.edu', from = 'dlradtrac@mayo.edu';
   //var smtpConn = new SMTPConnectionFactory.createSMTPConnection(host, port, auth, secure, username, password);
   // now gets host, port etc from MirthCOnnect settings 3-1-2014
   var smtpConn = new SMTPConnectionFactory.createSMTPConnection();
   smtpConn.send(to, cc, from, title, content);
}
