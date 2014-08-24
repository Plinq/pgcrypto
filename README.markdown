# PGCrypto for ActiveRecord::Base

**PGCrypto** adds seamless column-level encryption to your ActiveRecord::Base subclasses.

#### **WARNING TO 0.3.x USERS**:

PGCrypto's architecture has changed significantly as of 0.4.0. **PLEASE** read both the installation and upgrading sections below before you upgrade.

## Installation

Installing PGCrypto is pretty simple, but I'm going to give you the TL;DR first because the instructions can look more daunting than they are.

### TL;DR Install

1. Add it to your Gemfile and bundle: `gem "pgcrypto"`
2. Change `adapter: postgresql` to `adapter: pgcrypto` in `config/database.yml`.
3. Generate some files using `rails generate pgcrypto:install`.
4. Add encryptable columns using `add_column :users, :social_security_number, :binary`
5. Run pending migrations: `rake db:migrate`
6. Tell a model that it has an encrypted column using `has_encrypted_column :social_security_number`
7. Profit.

### Full Install Instructions

1. Add pgcrypto to your Gemfile and run `bundle install`.

		gem "pgcrypto"

2. Update your database adapter. If you were previously using the `postgresl` adapter, you should now be using a `pgcrypto` adapter, like so:

	#### `config/database.yml`:

		common: &common
		  adapter: pgcrypto
		  min_messages: warning

		development:
		  <<: *common
		  database: my_app_development
		  host: localhost

		test: &test
		  <<: *common
		  database: my_app_test
		  host: localhost

		production:
		  <<: *common
		  host: whatevs
		  database: my_app_production
		  username: whatevs
		  password: totally_not_my_app

	**NOTE:** if you are already using a PostgreSQL-descendant as an adapter (for example, the awesome [PostGIS adapter](https://github.com/rgeo/activerecord-postgis-adapter)), you'll need to read through the "Alternate Adapters" section below. But **don't panic**, it's 100% supported by PGCrypto.

3. Generate the required files using the included generator.

		rails generate pgcrypto:install


4. Edit the new initializer to point to your public and private GPG keys:

	#### `config/initializers/pgcrypto.rb`:

		PGCrypto.keys[:private] = {path: "~/.keys/private.key"}
		PGCrypto.keys[:public] = {path: "~/.keys/public.key"}

5. Add PGCrypto columns to your models in a migration. Something like the following:

		rails generate migration add_social_security_number_to_users

	And in the migration:

		class AddSocialSecurityNumberToUsers < ActiveRecord::Migration
		  def change
		    add_column :users, :social_security_number, :binary
		  end
		end

6. Tell the User class to encrypt and decrypt the `social_security_number` attribute on the fly:

		class User < ActiveRecord::Base
			# ... all kinds of neat stuff ...

			has_encrypted_column :social_security_number

			# ... some other fun stuff
		end

7. Profit

		User.create!(social_security_number: "466-99-1234") #=> #<User with stuff>
		User.last.social_security_number #=> "466-99-1234"

BAM. It looks innocuous on your end, but on the back end that beast is storing the social security number in
a GPG-encrypted column that can only be decrypted with your secure key.

### Rails 3.x and PostgreSQL extensions

PGCrypto will load the `pgcrypto` extension into your database if you haven't already, but this change will NOT get propagated
to your schema.rb file, so... go figure. You'll have to `CREATE EXTENSION IF NOT EXISTS pgcrypto` any database built from the
schema file (**HINT** that means your test databases).


## Upgrading from 0.3.x

If you've been on 0.3.x branch, the most important change is that **PGCrypto now uses database columns on models directly**. This means you don't need the `pgcrypto_columns` table anymore. Follow these steps to migrate your new app over!

1. BACK UP YOUR PRODUCTION DATABASE.

2. In `config/database.yml`, change `adapter: postgresql` to `adapter: pgcrypto`

2. Generate the upgrade files:

	`rails generate pgcrypto:upgrade`

3. Run the migration that gets generated. It will do three things:
	1. It will add encrypted columns directly to tables whose records have corresponding columns in the `pgcrypto_columns` table.
	2. It will move values from `pgcrypto_columns` into the appropriate columns on the parent models.
	3. It will drop the `pgcrypto_columns` table.

4. The `pgcrypto` method is being deprecated in favor of the more declarative `has_encrypted_column`. Any model that calls `pgcrypto` will start generating deprecation warnings. So g'head and update your models.

### Manual upgrade

If you don't trust my auto-generated migration, follow these steps:

1. Add columns directly to models' tables:

		add_column :users, :social_security_number, :pgcrypto

2. Run `rake pgcrypto:upgrade_columns` to copy `PGCrypto::Column` values directly onto your tables' new columns.

3. Generate a migration to drop the `pgcrypto_columns` table.

## Keys

If you want to bundle your public key with your application, PGCrypto will automatically load `RAILS_ROOT/.pgcrypto`,
so feel free to put your public key in there. You can also tell PGCrypto about your keys in a number of fun ways.
The most straightforward is to assign the actual content of the key manually:

	PGCrypto.keys[:private] = "-----BEGIN PGP PRIVATE KEY BLOCK----- ..."

You can also give it more specific stuff:

	PGCrypto.keys[:private] = {:path => ".private.key", :armored => false, :password => "myKeyPASSwhichizneededBRO"}

This is especially important if you password protect your private key files (and you SHOULD, for the record)!

I recommend deploy-time passing of your private key and password, to ensure it doesn't wind up in any long-term
storage on your server, since if you're using this library you presumably care a little bit about security:

	PGCrypto.keys[:private] = {:value => ENV['PRIVATE_KEY'], :password => ENV['PRIVATE_KEY_PASSWORD']}

## Alternate Adapters

If you're already using an adapter that isn't the PostgreSQL adapter, you'll want to tell PGCrypto so it can make sure it supports your extra stuff. The easiest way to do this is to tell it which adapter it should inherit from.

In `config/initializers/pgcrypto.rb`, add:

	PGCrypto.base_adapter = ActiveRecord::ConnectionAdapters:PostGISAdapter

...or whatever your adapter is. Then make sure you're telling `config/database.yml` to use `adapter: pgcrypto`.

## Warranty (or lack thereof)

As I mentioned before, this library is one HUGE hack. This is just scratching the surface of keeping your data secure.
For example, if you don't protect your log files, anyone who can read them can get your private and public keys and
decrypt whatever the hell they want. You'll also have to scrub your logs, because un-encrypted data is displayed right
alongside those private and public keys.

Basically, this will make it easy to start with asymmetric, GPG-based, column-level encryption in PostgreSQL. But that's about
it; the rest is up to you.

**As such,** the author and Delightful Widgets Inc. offer ***ABSOLUTELY NO GODDAMN WARRANTY***. Sorry, folks.

Copyright (C) 2012 Delightful Widgets, Inc. Built by Flip Sasser, Monkeypatcher Extraordinaire!
