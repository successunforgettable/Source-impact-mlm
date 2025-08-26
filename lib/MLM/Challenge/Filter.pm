package MLM::Challenge::Filter;

use strict;
use MLM::Filter;
use vars qw(@ISA);

@ISA = ('MLM::Filter');

sub topics {
    my $self = shift;
    my $ARGS = $self->{ARGS};
    
    if ($ARGS->{type} eq 'categories') {
        $self->{LISTS} = $self->model->get_challenge_categories();
    } elsif ($ARGS->{type} eq 'items') {
        $self->{LISTS} = $self->model->get_challenge_items($ARGS->{category_id});
    } elsif ($ARGS->{type} eq 'packages') {
        $self->{LISTS} = $self->model->get_challenge_packages($ARGS->{item_id});
    } elsif ($ARGS->{type} eq 'orders') {
        $self->{LISTS} = $self->model->get_member_challenge_orders($ARGS->{member_id});
    } else {
        # Default: show all packages
        $self->{LISTS} = $self->model->get_challenge_packages();
    }
    
    return;
}

sub insert {
    my $self = shift;
    my $ARGS = $self->{ARGS};
    
    if ($ARGS->{type} eq 'category') {
        return $self->error("Missing name") unless $ARGS->{name};
        return $self->error("Missing slug") unless $ARGS->{slug};
        
        my $id = $self->model->create_challenge_category($ARGS->{name}, $ARGS->{slug});
        $self->{LISTS} = [{ category_id => $id, name => $ARGS->{name}, slug => $ARGS->{slug} }];
        
    } elsif ($ARGS->{type} eq 'item') {
        return $self->error("Missing category_id") unless $ARGS->{category_id};
        return $self->error("Missing title") unless $ARGS->{title};
        return $self->error("Missing slug") unless $ARGS->{slug};
        
        my $id = $self->model->create_challenge_item(
            $ARGS->{category_id}, $ARGS->{title}, $ARGS->{slug}, 
            $ARGS->{description}, $ARGS->{image_url}
        );
        $self->{LISTS} = [{ item_id => $id }];
        
    } elsif ($ARGS->{type} eq 'package') {
        return $self->error("Missing item_id") unless $ARGS->{item_id};
        return $self->error("Missing phase_number") unless defined $ARGS->{phase_number};
        return $self->error("Missing title") unless $ARGS->{title};
        return $self->error("Missing price") unless defined $ARGS->{price};
        
        my $id = $self->model->create_challenge_package(
            $ARGS->{item_id}, $ARGS->{phase_number}, $ARGS->{title}, 
            $ARGS->{price}, $ARGS->{requires_prev} ? 1 : 0, $ARGS->{image_url}
        );
        $self->{LISTS} = [{ package_id => $id }];
    }
    
    return;
}

sub delete {
    my $self = shift;
    my $ARGS = $self->{ARGS};
    
    if ($ARGS->{type} eq 'category' && $ARGS->{category_id}) {
        $self->model->delete_challenge_category($ARGS->{category_id});
    } elsif ($ARGS->{type} eq 'item' && $ARGS->{item_id}) {
        $self->model->delete_challenge_item($ARGS->{item_id});
    } elsif ($ARGS->{type} eq 'package' && $ARGS->{package_id}) {
        $self->model->delete_challenge_package($ARGS->{package_id});
    }
    
    $self->{LISTS} = [];
    return;
}

sub unlock_phase {
    my $self = shift;
    my $ARGS = $self->{ARGS};
    
    return $self->error("Missing member_id") unless $ARGS->{member_id};
    return $self->error("Missing phase_number") unless defined $ARGS->{phase_number};
    
    $self->model->admin_unlock_member_phase($ARGS->{member_id}, $ARGS->{phase_number});
    $self->{LISTS} = [];
    
    return;
}

sub complete_phase {
    my $self = shift;
    my $ARGS = $self->{ARGS};
    
    return $self->error("Missing member_id") unless $ARGS->{member_id};
    return $self->error("Missing phase_number") unless defined $ARGS->{phase_number};
    
    $self->model->mark_member_phase_completed($ARGS->{member_id}, $ARGS->{phase_number});
    $self->{LISTS} = [];
    
    return;
}

sub member_progress {
    my $self = shift;
    my $ARGS = $self->{ARGS};
    
    return $self->error("Missing member_id") unless $ARGS->{member_id};
    
    $self->{LISTS} = $self->model->get_member_progress($ARGS->{member_id});
    
    return;
}

1;


