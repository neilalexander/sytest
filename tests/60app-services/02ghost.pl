multi_test "AS-ghosted users can use rooms via AS",
   requires => [qw( make_test_room make_as_user await_event_for await_as_event user as_user
                    can_join_room_by_id can_receive_room_message_locally )],

   do => sub {
      my ( $make_test_room, $make_as_user, $await_event_for, $await_as_event, $user, $as_user ) = @_;

      my $room_id;
      my $ghost;

      $make_test_room->( [ $user ] )
         ->SyTest::pass_on_done( "Created test room" )
      ->then( sub {
         ( $room_id ) = @_;

         $make_as_user->( "02ghost-1" )
            ->SyTest::pass_on_done( "Created AS ghost" )
      })->then( sub {
         ( $ghost ) = @_;

         Future->needs_all(
            $await_as_event->( "m.room.member" )->then( sub {
               my ( $event ) = @_;

               log_if_fail "AS event", $event;

               require_json_keys( $event, qw( content room_id ));

               $event->{room_id} eq $room_id or
                  die "Expected room_id to be $room_id";
               $event->{state_key} eq $ghost->user_id or
                  die "Expected state_key to be ${\$ghost->user_id}";

               require_json_keys( my $content = $event->{content}, qw( membership ) );

               $content->{membership} eq "join" or
                  die "Expected membership to be 'join'";

               Future->done;
            }),

            do_request_json_for( $as_user,
               method => "POST",
               uri    => "/api/v1/rooms/$room_id/join",
               params => {
                  user_id => $ghost->user_id,
               },

               content => {},
            )
         )
      })->SyTest::pass_on_done( "User joined room via AS" )
      ->then( sub {
         Future->needs_all(
            $await_as_event->( "m.room.message" )->then( sub {
               my ( $event ) = @_;

               log_if_fail "AS event", $event;

               require_json_keys( $event, qw( room_id user_id ));

               $event->{room_id} eq $room_id or
                  die "Expected room_id to be $room_id";
               $event->{user_id} eq $ghost->user_id or
                  die "Expected sender user_id to be ${\$ghost->user_id}";

               Future->done;
            }),

            do_request_json_for( $as_user,
               method => "POST",
               uri    => "/api/v1/rooms/$room_id/send/m.room.message",
               params => {
                  user_id => $ghost->user_id,
               },

               content => { msgtype => "m.text", body => "Message from AS directly" },
            )
         )
      })->SyTest::pass_on_done( "User posted message via AS" )
      ->then( sub {
         $await_event_for->( $user, sub {
            my ( $event ) = @_;
            return unless $event->{type} eq "m.room.message";
            return unless $event->{room_id} eq $room_id;

            log_if_fail "Event", $event;

            my $content = $event->{content};

            $content->{body} eq "Message from AS directly" or
               die "Expected 'body' as 'Message from AS directly'";
            $event->{user_id} eq $ghost->user_id or
               die "Expected sender user_id as ${\$ghost->user_id}";

            return 1;
         })->on_done( sub { "Creator received user's message" } )
      })->then_done(1);
   };

multi_test "AS-ghosted users can use rooms themselves",
   requires => [qw( make_test_room make_as_user await_event_for await_as_event user
                    can_join_room_by_id can_receive_room_message_locally )],

   do => sub {
      my ( $make_test_room, $make_as_user, $await_event_for, $await_as_event, $user ) = @_;

      my $room_id;
      my $ghost;

      $make_test_room->( [ $user ] )
         ->SyTest::pass_on_done( "Created test room" )
      ->then( sub {
         ( $room_id ) = @_;

         $make_as_user->( "02ghost-2" )
            ->SyTest::pass_on_done( "Created AS ghost" )
      })->then( sub {
         ( $ghost ) = @_;

         Future->needs_all(
            $await_as_event->( "m.room.member" )->then( sub {
               my ( $event ) = @_;

               log_if_fail "AS event", $event;

               require_json_keys( $event, qw( content room_id ));

               $event->{room_id} eq $room_id or
                  die "Expected room_id to be $room_id";

               require_json_keys( my $content = $event->{content}, qw( membership ) );

               $content->{membership} eq "join" or
                  die "Expected membership to be 'join'";

               Future->done;
            }),

            do_request_json_for( $ghost,
               method => "POST",
               uri    => "/api/v1/rooms/$room_id/join",

               content => {},
            )
         )
      })->SyTest::pass_on_done( "Ghost joined room themselves" )
      ->then( sub {
         Future->needs_all(
            $await_as_event->( "m.room.message" )->then( sub {
               my ( $event ) = @_;

               log_if_fail "AS event", $event;

               require_json_keys( $event, qw( room_id user_id ));

               $event->{room_id} eq $room_id or
                  die "Expected room_id to be $room_id";
               $event->{user_id} eq $ghost->user_id or
                  die "Expected sender user_id to be ${\$ghost->user_id}";

               Future->done;
            }),

            do_request_json_for( $ghost,
               method => "POST",
               uri    => "/api/v1/rooms/$room_id/send/m.room.message",

               content => { msgtype => "m.text", body => "Message from AS Ghost" },
            )
         )
      })->SyTest::pass_on_done( "Ghost posted message themselves" )
      ->then( sub {
         $await_event_for->( $user, sub {
            my ( $event ) = @_;
            return unless $event->{type} eq "m.room.message";
            return unless $event->{room_id} eq $room_id;

            log_if_fail "Event", $event;

            my $content = $event->{content};

            $content->{body} eq "Message from AS Ghost" or
               die "Expected 'body' as 'Message from AS Ghost'";
            $event->{user_id} eq $ghost->user_id or
               die "Expected sender user_id as ${\$ghost->user_id}";

            return 1;
         })->SyTest::pass_on_done( "Creator received ghost's message" )
      })->then_done(1);
   };
