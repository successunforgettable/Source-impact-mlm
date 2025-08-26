package MLM::Phase::Filter;

use strict;
use MLM::Filter;
use vars qw(@ISA);

@ISA = ('MLM::Filter');

sub unlock_phase {
    my $self = shift;
    my $ARGS = $self->{ARGS};
    
    return $self->error("Missing memberid") unless $ARGS->{memberid};
    return $self->error("Missing phase_number") unless defined $ARGS->{phase_number};
    
    my $err = $self->model->admin_unlock_phase($ARGS->{memberid}, $ARGS->{phase_number});
    return $err if $err;
    
    $self->{LISTS} = [];
    return;
}

sub member_progress {
    my $self = shift;
    my $ARGS = $self->{ARGS};
    
    return $self->error("Missing memberid") unless $ARGS->{memberid};
    
    my $progress = $self->model->get_member_progress($ARGS->{memberid});
    $self->{LISTS} = $progress || [];
    
    return;
}

sub available_phases {
    my $self = shift;
    my $ARGS = $self->{ARGS};
    
    return $self->error("Missing memberid") unless $ARGS->{memberid};
    
    my $phases = $self->model->get_available_phases($ARGS->{memberid});
    $self->{LISTS} = $phases || [];
    
    return;
}

1;


