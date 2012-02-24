PGCrypto for ActiveRecord::Base
===

**PGCrypto** adds seamless column-level encryption to your ActiveRecord::Base subclasses. It's literally *one giant hack,*
so I make no promises as to its efficacy in the real world beyond my tiny, Rails-3.2-based utopia.

Installation
-

You need to have PGCrypto installed before this guy will work. [LMGTFY](http://lmgtfy.com/?q=how+to+install+pgcrypto).

1. Add this to your Gemfile:
	
		gem "pgcrypto"

2. Do this now:
	
		bundle

3. Now point it to your public and private GPG keys:
	
		PGCrypto.keys[:private] = {:path => "~/.keys/private.key"}
		PGCrypto.keys[:public] = {:path => "~/.keys/public.key"}

4. PGCrypto columns are named `attribute_encrypted` and in the `binary` format, so do something like this:
		
		add_column :users, :social\_security\_number\_encrypted, :binary

5. Tell the User class to encrypt and decrypt the `social_security_number` attribute on the fly:
		
		class User < ActiveRecord::Base
			# ... all kinds of neat stuff ...

			pgcrypto :social_security_number

			# ... some other fun stuff
		end

6. Profit
		
		User.create!(:social_security_number => "466-99-1234") #=> #<User with stuff>
		User.last.social_security_number #=> "466-99-1234"

BAM. It looks innocuous on your end, but on the back end that beast is storing the social security number in
a GPG-encrypted column that can only be decrypted with your secure key.

Keys
-

You can tell PGCrypto about your keys in a number of fun ways. The most straightforward is to assign the actual
content of the key manually:

	PGCrypto.keys[:private] = "-----BEGIN PGP PRIVATE KEY BLOCK----- ..."

You can also give it more specific stuff:

	PGCrypto.keys[:private] = {:path => ".private.key", :armored => true, :password => "myKeyPASSwhichizneededBRO"}

This is especially important if you password protect your private key files (and you SHOULD, for the record)!

You can also specify different keys for different purposes:

	PGCrypto.keys[:user_public] = {:path => '.user_public.key'}
	PGCrypto.keys[:user_private] = {:path => '.user_private.key'}

If you do that, just tell PGCrypto which keys to use on which columns, using an optional hash on the end of the `pgcrypto` call:

	class User < ActiveRecord::Base
		pgcrypto :social_security_number, :private_key => :user_private, :public_key => :user_public
	end

FINALLY, if you want to bundle your public key with your application, PGCrypto will automatically load Rails.root/.pgcrypto,
so feel free to put your public key in there. I recommend deploy-time passing of your private key and password, to ensure it
doesn't wind up in any long-term storage on the server:

	PGCrypto.keys[:private] = {:value => ENV['PRIVATE_KEY'], :password => ENV['PRIVATE_KEY_PASSWORD']}

Warranty
-

As I mentioned before, this library is one HUGE hack. When you're using something like this alongside data that needs to be
well protected, this is just scratching the surface. This will make it easy to follow the basics of asymmetric, GPG-based,
column-level encryption in PostgreSQL but that's about it.

As such, the author and Delightful Widgets Inc. offer ABSOLUTELY NO GODDAMN WARRANTY. As I mentioned, this works great in our
Rails 3.2 world, but YMMV if your version of Arel or ActiveRecord are ahead or behind ours. Sorry, folks.

WTF NO TESTS?!!
-

Nope. We built this inside of a production application, and used its test suite to debug everything. Since this is really just
a preview release, I haven't written a suite for it yet. Sorry.

Authored by Flip Sasser
Copyright (C) 2012 Delightful Widgets, Inc.
