use inc::Module::Install;
name 'WWW-Wikipedia-List';
all_from 'lib/WWW/Wikipedia/List.pm';

requires 'Cache::FileCache' => 1.06;
requires 'Lingua::JA::Moji' => 0.08;
requires 'XML::Simple'      => 2.18;
requires 'URI'              => 1.58;
requires 'Carp'             => 1.20;
requires 'Coro'             => 6.01;
requires 'FurlX::Coro'      => 0;

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
