package Dict::Learn::Main::ResultSet::TestSession 0.1;
use base 'DBIx::Class::ResultSet';

use namespace::autoclean;

use common::sense;

use Data::Printer;

sub export_data {
  my ($self) = @_;
  my $rs = $self->search({ }, { });
  $rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
  $rs->all()
}

sub import_data {
  my ($self, $data) = @_;
  $self->populate($data);
  return 1
}

sub clear_data {
  my ($self) = @_;
  $self->delete_all()
}

sub add {
  my ($self, $test_id, $total_score, $result) = @_;
  my $test_session = $self->create({
    test_id => $test_id,
    score   => $total_score,
  });
  my @data;
  for my $item (@{ $result }) {
    for my $userdata (@{ $item->{user} }) {
      next unless defined $userdata;
      push @data => {
        test_session_id => $test_session->test_session_id,
        word_id         => $item->{word_id},
        data            => $userdata->[0],
        score           => $userdata->[1],
      }
    }
  }
  $self->result_source->schema->resultset('TestSessionData')->populate(\@data);
}

sub get_all {
  my ($self, $test_id) = @_;
  my $rs = $self->search({
    'me.test_id'  => $test_id,
  },{
    prefetch => { 'data' => [ 'word_id' ] },
    group_by => [ 'data.word_id' ],
    order_by => [{ -asc => 'me.test_session_id' },
                 { -asc => 'data.test_session_data_id' }],
  });
  $rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
  $rs->all()
}

sub get_words_stats {
  my ($self, $test_id) = @_;
  my $rs = $self->result_source->schema->resultset('TestSessionData')->search({
    # 'me.test_id'  => $test_id,
  },{
    select    => [ { count => [ 'me.test_session_data_id' ], -as => 'wcount' },
                   { sum   => [ 'me.score' ], -as => 'sumscore' }],
    prefetch  => [ 'word_id' ],
    group_by  => [ 'me.word_id' ],
    order_by  => [{ -asc => 'sumscore' }],
  });
  $rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
  # TODO: find out how to do this using DBIx::Class
  my @a = sort { $b->{perc} <=> $a->{perc} } map {
    $_->{word} = $_->{word_id}{word}." / ".$_->{word_id}{word2}." / ".$_->{word_id}{word3};
    $_->{sumscore} *= 2;
    $_->{perc} = $_->{sumscore}*100/$_->{wcount};
    $_
  } $rs->all();
  @a
}

1;