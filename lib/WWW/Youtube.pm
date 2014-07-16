#module-starter --module=youtube --author="Daniel Torres" --email=daniel.torres0085@gmail.com
# Aug 27 2012
# youtube interface
package WWW::Youtube;
our $VERSION = '1.0';
use Data::Dumper;
use HTTP::Request::Common;
use File::Slurp;
use strict;
use warnings FATAL => 'all';
use Carp qw(croak);
use Moose;
use Net::SSL (); # From Crypt-SSLeay
use LWP::UserAgent;
use HTTP::Cookies;

$Net::HTTPS::SSL_SOCKET_CLASS = "Net::SSL"; # Force use of Net::SSL for proxy compatibility

{
has 'username', is => 'rw', isa => 'Str',required => 1;	
has 'password', is => 'rw', isa => 'Str',required => 1;

#has key      => ( isa => 'Str', is => 'rw', default => 'AI39si75YnvMRPcFKUG6numWqT3eQ1GgiBwu5BE5w8edMPAA6VrYaVQeEw3RqMCCXfXIaHIgkFRVtY4Zb2QaWbQAo1LUmsyJLg');
has key      => ( isa => 'Str', is => 'rw', default => 'AI39si7iJ5TSVP3U_j4g3GGNZeI6uJl6oPLMxiyMst24zo1FEgnLzcG4iSE0t2pLvi-O03cW918xz9JFaf_Hn-XwRTTK7i1Img');

has proxy_host      => ( isa => 'Str', is => 'rw', default => '' );
has proxy_port      => ( isa => 'Str', is => 'rw', default => '' );
has proxy_user      => ( isa => 'Str', is => 'rw', default => '' );
has proxy_pass      => ( isa => 'Str', is => 'rw', default => '' );
has proxy_env      => ( isa => 'Str', is => 'rw', default => '' );

has browser  => ( isa => 'Object', is => 'rw', lazy => 1, builder => '_build_browser' );

###################################### blog  functions ###################

####### login  ###########3
sub login
{
my $self = shift;
my %options = @_;
my $username = $self->username;
my $password = $self->password;

my $post_data = {Email => $username, 
				Passwd => $password, 
				service => 'youtube'};				

my $response = $self->dispatch(url =>"https://www.google.com/accounts/ClientLogin", method => 'POST',post_data =>$post_data);

# Check success, parsing Google error message, if available.
unless ($response->is_success) 
{
  my $error_msg = ($response->content =~ /\bError=(.+)/)[0] || 'Google error message unavailable';
  die 'HTTP error when trying to authenticate: ' . $response->status_line . " ($error_msg)";
}

# Parse authentication token and set it as default header for user agent object.
my ($auth_token) = $response->content =~ /\bAuth=(.+)/
  or die 'Authentication token not found in the response: ' . $response->content;
$self->browser->default_header(Authorization => "GoogleLogin auth=$auth_token");

return 1;
}

###### upload the video #####
sub upload_video
{
my $self = shift;
my ($title,$description,$category,$video_file) = @_;
my $key = $self->key;

my $xml_post = '<?xml version=\'1.0\' encoding=\'UTF-8\'?><ns0:entry xmlns:ns0="http://www.w3.org/2005/Atom"><ns1:group xmlns:ns1="http://search.yahoo.com/mrss/"><ns1:keywords /><ns1:description type="plain">DESCRIPTION</ns1:description><ns1:title>TITLE</ns1:title><ns1:category label="CATEGORY" scheme="http://gdata.youtube.com/schemas/2007/categories.cat">CATEGORY</ns1:category></ns1:group></ns0:entry>';

$xml_post =~ s/TITLE/$title/; 
$xml_post =~ s/DESCRIPTION/$description/; 
$xml_post =~ s/CATEGORY/$category/g; 


$self->browser->default_header('Accept-Encoding' => "identity");
$self->browser->default_header('X-GData-Key' => "key=$key");
$self->browser->default_header('X-Gdata-Client' => "tokland-youtube_upload");
$self->browser->default_header('Content-Type' => "application/atom+xml");

my $response = $self->dispatch(url =>"http://gdata.youtube.com/action/GetUploadToken",method => 'POST_FILE',post_data =>$xml_post);
my $status = $response->status_line;
print "status $status \n";
my $content = $response->content;

$content =~ /<url>(.*?)<\/url>/;  
my $url = $1; 

$content =~ /<token>(.*?)<\/token>/;  
my $token = $1; 

################ read video ###############
my %args;
my $buf ;
my $buf_ref = $args{'buf'} || \$buf ;
my $value = read_file( $video_file , binmode => ':raw' , scalar_ref => 1 );
################ ########## ###############

my $post_data = {'token' => $token,
			  'file' => ["$video_file"]};

$self->browser->default_header('Accept' => "*/*");
$self->browser->default_header('X-Gdata-Client' => "");
$self->browser->default_header('X-GData-Key' => "");


$response = $self->dispatch(url => $url."?nexturl=http://code.google.com/p/youtube-upload" ,method => 'POST_MULTIPART',post_data =>$post_data);
$content = $response->as_string;

$content =~ /id=(.*?)\n/;  
my $id = $1; 
return $id;
}    


###################################### internal functions ###################
sub dispatch {    
my $self = shift;
my %options = @_;

my $method = $options{ method };
my $url = $options{ url };
my $post_data = $options{ post_data };

my $response = '';
if ($method eq 'GET')
  { $response = $self->browser->get($url);}
  
if ($method eq 'POST')
  {       
   my $post_data = $options{ post_data };     
   $response = $self->browser->post($url,$post_data);    
  }  
  
if ($method eq 'POST_FILE')
  {         	    
    $response = $self->browser->post( $url, Content_Type => 'application/atom+xml', Content => $post_data );                 
  }  
  
if ($method eq 'POST_MULTIPART')
  {    	   
   my $post_data = $options{ post_data };        
   $response = $self->browser->post($url,Content_Type => 'multipart/form-data', Content => $post_data);           
  }     
  
return $response;
}


sub _build_browser {    
my $self = shift;

my $proxy_host = $self->proxy_host;
my $proxy_port = $self->proxy_port;
my $proxy_user = $self->proxy_user;
my $proxy_pass = $self->proxy_pass;
my $proxy_env = $self->proxy_env;

my $browser = LWP::UserAgent->new;
$browser->timeout(10);
$browser->show_progress(1);
$browser->cookie_jar(HTTP::Cookies->new(file => "cookies.txt", autosave => 1));
$browser->default_header('User-Agent' => 'Mozilla/5.0 (X11; Ubuntu; Linux i686; rv:11.0) Gecko/20100101 Firefox/11.0'); 
print "proxy_env $proxy_env \n";

if ( $proxy_env eq 'ENV' )
{
$Net::HTTPS::SSL_SOCKET_CLASS = "Net::SSL"; # Force use of Net::SSL
$ENV{HTTPS_PROXY} = "http://".$proxy_host.":".$proxy_port;
}
else
{
  if (($proxy_user ne "") && ($proxy_host ne ""))
  {
   $browser->proxy(['http', 'https'], 'http://'.$proxy_user.':'.$proxy_pass.'@'.$proxy_host.':'.$proxy_port); # Using a private proxy
  }
  elsif ($proxy_host ne "")
    { $browser->proxy(['http', 'https'], 'http://'.$proxy_host.':'.$proxy_port);} # Using a public proxy
  else
    { $browser->env_proxy;} # No proxy       
} 
    
return $browser;
}

}

1;


__END__

=head1 NAME

WWW::Youtube - Youtube interface.


=head1 SYNOPSIS


Usage:

use WWW::Youtube;

$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;

my $youtube = WWW::Youtube->new( username => USERNAME@gmail.com,
					password => PASS);
					

=head1 DESCRIPTION

Youtube interface

=head1 FUNCTIONS

=head2 constructor

    my $youtube = WWW::Youtube->new( username => USERNAME@gmail.com,
					password => PASS);

=head2 login

    $youtube->login;

Login to the Youtube account with the username and password provided. You MUST call this function before call any other function.

=head2 upload_video

	my $video_file = 'fun.mp4';
	my $title = "my title final";
	my $description = "my content final";
	my $category = 'Comedy';
     
	$id = $youtube->upload_video($title,$description,$category, $video_file);

	print "url http://www.youtube.com/watch?v=$id \n";


Upload a video

=head2 dispatch
 Internal function         
                  
=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html
=cut
