my $user_fixture = local_user_fixture();

# An incrementing parameter for initialSync to defeat the caching mechanism and ensure fresh results every time
my $initial_sync_limit = 1;

test "POST /createRoom makes a public room",
   requires => [ $user_fixture,
                 qw( can_initial_sync )],

   critical => 1,

   do => sub {
      my ( $user ) = @_;

      do_request_json_for( $user,
         method => "POST",
         uri    => "/api/v1/createRoom",

         content => {
            visibility      => "public",
            # This is just the localpart
            room_alias_name => "30room-create",
         },
      )->then( sub {
         my ( $body ) = @_;

         assert_json_keys( $body, qw( room_id room_alias ));
         assert_json_nonempty_string( $body->{room_id} );
         assert_json_nonempty_string( $body->{room_alias} );

         Future->done(1);
      });
   },

   check => sub {
      my ( $user ) = @_;

      # Change the limit for each request to defeat caching
      matrix_initialsync( $user, limit => $initial_sync_limit++ )->then( sub {
         my ( $body ) = @_;

         assert_json_list( $body->{rooms} );
         @{ $body->{rooms} } or
            die "Expected a list of rooms";

         Future->done(1);
      });
   };

test "POST /createRoom makes a private room",
   requires => [ $user_fixture ],

   proves => [qw( can_create_private_room )],

   do => sub {
      my ( $user ) = @_;

      do_request_json_for( $user,
         method => "POST",
         uri    => "/api/v1/createRoom",

         content => {
            visibility => "private",
         },
      )->then( sub {
         my ( $body ) = @_;

         assert_json_keys( $body, qw( room_id ));
         assert_json_nonempty_string( $body->{room_id} );

         Future->done(1);
      });
   };

test "POST /createRoom makes a private room with invites",
   requires => [ $user_fixture, local_user_fixture(),
                 qw( can_create_private_room )],

   proves => [qw( can_create_private_room_with_invite )],

   do => sub {
      my ( $user, $invitee ) = @_;

      do_request_json_for( $user,
         method => "POST",
         uri    => "/api/v1/createRoom",

         content => {
            visibility => "private",
            # TODO: This doesn't actually appear in the API docs yet
            invite     => [ $invitee->user_id ],
         },
      )->then( sub {
         my ( $body ) = @_;

         assert_json_keys( $body, qw( room_id ));
         assert_json_nonempty_string( $body->{room_id} );

         Future->done(1);
      });
   };

push our @EXPORT, qw( matrix_create_room );

sub matrix_create_room
{
   my ( $user, %opts ) = @_;
   is_User( $user ) or croak "Expected a User; got $user";

   do_request_json_for( $user,
      method => "POST",
      uri    => "/api/v1/createRoom",

      content => {
         visibility => $opts{visibility} || "public",
         ( defined $opts{room_alias_name} ?
            ( room_alias_name => $opts{room_alias_name} ) : () ),
         ( defined $opts{invite} ?
            ( invite => $opts{invite} ) : () ),
         ( defined $opts{invite_3pid} ?
            ( invite_3pid => $opts{invite_3pid} ) : () ),
         ( defined $opts{creation_content} ?
            ( creation_content => $opts{creation_content} ) : () ),
      }
   )->then( sub {
      my ( $body ) = @_;

      Future->done( $body->{room_id}, $body->{room_alias} );
   });
}
