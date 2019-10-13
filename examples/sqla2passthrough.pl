use strict;
use warnings;
use Devel::Dwarn;
use With::Roles;
{
  package MySchema;
  use Object::Tap;
  use base qw(DBIx::Class::Schema);
  use DBIx::Class::ResultSource::Table;
  __PACKAGE__->register_source(
    Foo => DBIx::Class::ResultSource::Table->new({ name => 'foo' })
             ->$_tap(add_columns => qw(x y z))
  );
  __PACKAGE__->register_source(
    Bar => DBIx::Class::ResultSource::Table->new({ name => 'bar' })
             ->$_tap(add_columns => qw(x y1 y2 z))
  );
}
{
  package MyScratchpad;
  use DBIx::Class::SQLMaker::Role::SQLA2Passthrough qw(on);
  MySchema->source('Foo')->add_relationship(bars => 'Bar' => on {
    +{ 'foreign.x' => 'self.x',
       'self.y' => { -between => [ qw(foreign.y1 foreign.y2) ] }
    };
  });
}

my $s = MySchema->connect('dbi:SQLite:dbname=:memory:');
::Dwarn([ $s->source('Foo')->columns ]);

my $rs = $s->resultset('Foo')->search({ z => 1 });

::Dwarn(${$rs->as_query}->[0]);

$s->storage->ensure_connected;

$s->storage
  ->sql_maker
  ->with::roles('DBIx::Class::SQLMaker::Role::SQLA2Passthrough')
  ->plugin('+ExtraClauses')
  ->plugin('+BangOverrides');

warn ref($s->storage->sql_maker);

my $rs2 = $s->resultset('Foo')->search({
  -op => [ '=', { -ident => 'outer.y' }, { -ident => 'me.x' } ]
}, {
  'select' => [ 'me.x', { -ident => 'me.z' } ],
  '!with' => [ outer => $rs->get_column('x')->as_query ],
});

::Dwarn(${$rs2->as_query}->[0]);

my $rs3 = $s->resultset('Foo')
            ->search({}, { prefetch => 'bars' });

::Dwarn(${$rs3->as_query}->[0]);
