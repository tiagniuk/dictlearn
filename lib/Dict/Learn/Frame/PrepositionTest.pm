package Dict::Learn::Frame::PrepositionTest;

use Wx qw[:everything];
use Wx::Event qw[:everything];

use Data::Printer;

use Moose;
use MooseX::NonMoose;
extends 'Wx::Panel';

use Carp qw[ croak confess ];
use Const::Fast;
use List::Util qw(shuffle sum);

use common::sense;

use Database;
use Dict::Learn::Dictionary;

const my $TEST_ID => 2;

=head1 NAME

Dict::Learn::Frame::PrepositionTest

=head1 DESCRIPTION

TODO add description

=head1 ATTRIBUTES

=cut

=head2 parent

TODO add description

=cut

has parent => (
    is  => 'ro',
    isa => 'Dict::Learn::Frame',
);

=head2 vbox

TODO add description

=cut

has vbox => (
    is         => 'ro',
    isa        => 'Wx::BoxSizer',
    lazy_build => 1,
);

sub _build_vbox {
    my ($self) = @_;

    my $vbox = Wx::BoxSizer->new(wxVERTICAL);
    $vbox->Add($self->position,      0, wxEXPAND,         0);
    $vbox->Add($self->translations,  0, wxTOP | wxEXPAND, 20);
    $vbox->Add($self->hbox_exercise, 0, wxTOP | wxEXPAND, 20);
    $vbox->Add($self->hbox,          0, wxTOP | wxEXPAND, 20);

    return $vbox;
}

=head2 hbox_exercise

TODO add description

=cut

has hbox_exercise => (
    is      => 'ro',
    isa     => 'Wx::BoxSizer',
    lazy    => 1,
    default => sub { Wx::BoxSizer->new(wxHORIZONTAL) }
);

=head2 hbox

TODO add description

=cut

has hbox => (
    is         => 'ro',
    isa        => 'Wx::BoxSizer',
    lazy_build => 1,
);

sub _build_hbox {
    my ($self) = @_;

    my $hbox = Wx::BoxSizer->new(wxHORIZONTAL);

    $hbox->Add($self->btn_prev,   0, wxALL | wxEXPAND,  0);
    $hbox->Add($self->btn_next,   0, wxALL | wxEXPAND,  0);
    $hbox->Add($self->btn_reset,  0, wxLEFT | wxEXPAND, 40);
    $hbox->Add($self->btn_giveup, 0, wxLEFT | wxEXPAND, 40);

    return $hbox;
}

=head2 position

TODO add description

=cut

has position => (
    is      => 'ro',
    isa     => 'Wx::StaticText',
    default => sub {
        Wx::StaticText->new(shift, wxID_ANY, '', wxDefaultPosition,
            wxDefaultSize, wxALIGN_LEFT);
    },
);

=head2 translations

TODO add description

=cut

has translations => (
    is      => 'ro',
    isa     => 'Wx::StaticText',
    default => sub {
        Wx::StaticText->new(shift, wxID_ANY, '', wxDefaultPosition,
            wxDefaultSize, wxALIGN_LEFT);
    },
);

=head2 btn_prev

TODO add description

=cut

has btn_prev => (
    is      => 'ro',
    isa     => 'Wx::Button',
    default => sub {
        Wx::Button->new(shift, wxID_ANY, 'Prev', wxDefaultPosition,
            wxDefaultSize);
    },
);

=head2 btn_next

TODO add description

=cut

has btn_next => (
    is      => 'ro',
    isa     => 'Wx::Button',
    default => sub {
        Wx::Button->new(shift, wxID_ANY, 'Next', wxDefaultPosition,
            wxDefaultSize);
    },
);

=head2 btn_reset

TODO add description

=cut

has btn_reset => (
    is      => 'ro',
    isa     => 'Wx::Button',
    default => sub {
        Wx::Button->new(shift, wxID_ANY, 'Reset', wxDefaultPosition,
            wxDefaultSize);
    },
);

=head2 btn_giveup

TODO add description

=cut

has btn_giveup => (
    is      => 'ro',
    isa     => 'Wx::Button',
    default => sub {
        Wx::Button->new(shift, wxID_ANY, 'Give up', wxDefaultPosition,
            wxDefaultSize);
    },
);

=head2 exercise

Exercise

=cut

has exercise => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
    clearer => 'clear_exercise',
);

=head2 pos

TODO add description

=cut

has pos => (
    is      => 'rw',
    isa     => 'Int',
    lazy    => 1,
    default => sub { shift->min },
    trigger => sub {
        my ($self, $pos) = @_;

        $self->_render_position($pos);
    },
);

=head2 min

TODO add description

=cut

has min => (
    is      => 'ro',
    isa     => 'Int',
    lazy    => 1,
    default => 3,
);

=head2 min

TODO add description

=cut

has max => (
    is      => 'rw',
    isa     => 'Int',
    lazy    => 1,
    default => sub { shift->min },
);

=item preps

Prepositions list

=cut

has preps => (
    is         => 'ro',
    isa        => 'ArrayRef',
    lazy_build => 1,
);

sub _build_preps {
    my $self = shift;

    my $preps;

    Dict::Learn::Dictionary->cb(
        sub {
            my $dict = shift;

            my $prepositions_rs
                = Database->schema->resultset('Word')->search(
                {
                    'partofspeech.abbr' => 'pre',
                    'rel_words.dictionary_id' => $dict->curr_id
                },
                {
                    join     => { rel_words => 'partofspeech' },
                    group_by => 'me.word',
                    order_by => { -asc => 'me.word' }
                }
                );
            $preps = [
                # sort it by length in descending order,
                # because we need 'out of' go before 'of'
                sort { length $b <=> length $a }
                map { $_->word } $prepositions_rs->all()
            ];
        }
    );

    return $preps;
}


=head1 METHODS

=cut

sub FOREIGNBUILDARGS {
    my ($class, $parent, @args) = @_;

    return @args;
}

sub BUILDARGS {
    my ($class, $parent) = @_;

    return { parent => $parent };
}

sub BUILD {
    my ($self, @args) = @_;

    EVT_BUTTON($self, $self->btn_prev,   \&prev_step);
    EVT_BUTTON($self, $self->btn_next,   \&next_step);
    EVT_BUTTON($self, $self->btn_reset,  \&reset_session);
    EVT_BUTTON($self, $self->btn_giveup, \&giveup_step);

    $self->SetSizer($self->vbox);
    $self->Layout();
    $self->vbox->Fit($self);
    
    Dict::Learn::Dictionary->cb(
        sub {
            $self->init();
        }
    );
}

sub init {
    my ($self) = @_;

    $self->max(9);
    $self->pos(0);
    $self->exercise([]);

    my $lang_id
        = Dict::Learn::Dictionary->curr->{language_orig_id}{language_id};

    my $phrase_rs
        = Database->schema->resultset('Word')->search(
        {
            'me.lang_id' => $lang_id,
            'test_words.test_category_id' => 37,
        },
        {
            join => [ 'rel_words', 'test_words' ],
        }
        );

    while (my $dbix_phrase = $phrase_rs->next) {
        push @{ $self->exercise },
            {
                phrase_id    => $dbix_phrase->word_id,
                phrase       => $dbix_phrase->word,
                preps        => [],
                answer       => [],
                widgets      => [],
                result       => [],
                score        => 0,
                translations => [
                    map {
                            {
                                phrase_id => $_->word_id,
                                phrase => $_->word
                            }
                    } $dbix_phrase->words
                ]
            };
    }

    # Shuffle the exercise
    $self->exercise([(shuffle @{ $self->exercise })[0 .. $self->max]]);

    # load the first step
    $self->load_step(0);
}

sub load_step {
    my ($self, $step_no) = @_;

    # At first, clear all widgets inside the sizer
    # (1 - means destroy all widgets)
    $self->hbox_exercise->Clear(1);

    my $step = $self->exercise->[$step_no];
    $self->translations->SetLabel(join "\n",
        map { $_->{phrase} } @{ $step->{translations} });

    my $phrase = $step->{phrase};
    my (@chunks, @used_preps, @widgets);
    my @words = split /\s/, $step->{phrase};
    for my $word (@words) {
        for my $prep (@{ $self->preps }) {
            if ($word eq $prep || $word =~ /\b$prep\b/i) {
                push @used_preps, $prep;
            }
        }
    }

    $step->{preps} = [ @used_preps ];

    for my $prep (@used_preps) {
        my @parts = split /\b$prep\b/i, $phrase, 2;
        if (@parts > 1) {
            push @chunks, $parts[0];
            $phrase = $parts[1];
        }
    }
    push(@chunks, $phrase) if $phrase;

    for my $chunk (@chunks) {
        if ($chunk) {
            push @widgets,
                Wx::StaticText->new($self, wxID_ANY, $chunk,
                wxDefaultPosition, wxDefaultSize, wxALIGN_LEFT);
        }
        if (shift @used_preps) {
            my $textctrl
                = Wx::TextCtrl->new($self, wxID_ANY, '', wxDefaultPosition,
                wxDefaultSize, wxTE_LEFT);
            push @widgets, $textctrl;
            push $step->{widgets}, $textctrl;
        }
    }

    for my $widget (@widgets) {
        $self->hbox_exercise->Add($widget, 0, wxRIGHT, 5);
    }

    $self->Layout();
}

sub next_step {
    my ($self) = @_;

    my $step = $self->exercise->[$self->pos];
    for my $textctrl (@{ $step->{widgets} }) {
        push @{ $step->{answer} }, $textctrl->GetValue;
    }

    if ($self->pos + 1 > $self->max) {
        # finish
        $self->calc_result();
        $self->init();
        return;
    }
    $self->pos($self->pos + 1);
    $self->load_step($self->pos);
}

sub prev_step {
    my ($self) = @_;

    return if $self->pos - 1 < 0;

    $self->pos($self->pos - 1);
    $self->load_step($self->pos);
}

sub calc_result {
    my ($self) = @_;

    my $total_score = 0;
    for my $step (@{ $self->exercise }) {
        my $count = scalar @{ $step->{answer} };
        for my $i (0 .. $count - 1) {
            my $answer = $step->{answer}[$i];
            my $correct_prep = $step->{preps}[$i];
            $step->{result}[$i] = (lc $correct_prep eq lc $answer ? 1 : 0);
        }
        my $sm = sum @{ $step->{result} };
        $step->{score} = sum(@{ $step->{result} }) / ($count || 1);
        $total_score += $step->{score};
    }

    my $i = 0;
    say;
    say "Session summary:";
    for my $step (@{ $self->exercise }) {
        printf "%02d - [score: %.1f] - [answers: %s] - %s\n",
            ++$i, $step->{score},
            join(', ', @{ $step->{answer} }), $step->{phrase};
    }
    say;
    printf "Total score: %d/%d (%d%%)\n", $total_score,
        scalar @{ $self->exercise },
        ($total_score / scalar @{ $self->exercise }) * 100;
}

sub reset_session {
    my ($self) = @_;

    $self->init();
}

sub _render_position {
    my ($self) = @_;

    $self->position->SetLabel(
        sprintf '%00d/%00d',
        $self->pos + 1,
        $self->max + 1
    );
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
