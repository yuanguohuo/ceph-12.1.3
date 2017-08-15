// Copyright (C) 2014 Andrzej Krzemienski.
//
// Use, modification, and distribution is subject to the Boost Software
// License, Version 1.0. (See accompanying file LICENSE_1_0.txt or copy at
// http://www.boost.org/LICENSE_1_0.txt)
//
// See http://www.boost.org/lib/optional for documentation.
//
// You are welcome to contact the author at:
//  akrzemi1@gmail.com

#include "boost/optional/optional.hpp"

#ifdef __BORLANDC__
#pragma hdrstop
#endif

#include "boost/core/lightweight_test.hpp"
#include "boost/none.hpp"

//#ifndef BOOST_OPTIONAL_NO_CONVERTING_COPY_CTOR

using boost::optional;
using boost::none;

void test_optional_optional_T()
{
  optional<int> oi1 (1), oiN;
  optional< optional<int> > ooi1 (oi1), ooiN(oiN);
  
  BOOST_TEST(ooi1);
  BOOST_TEST(*ooi1);
  BOOST_TEST_EQ(**ooi1, 1);
  
  BOOST_TEST(ooiN);
  BOOST_TEST(!*ooiN);
}  

int main()
{
    test_optional_optional_T();
  
    return boost::report_errors();
}
