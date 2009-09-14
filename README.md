Capistrano Taffy (Database, SSH recipes)
================================================

**Capistrano recipes for deploying databases and other common tasks (managing database.yml, importing/exporting/transfering databases, SSH authorization etc.)**

Features
------------------------------------------------

* Adds database transfer recipes (via [`Taps`]("http://github.com/ricardochimal/taps"))
* Manage `database.yml` (Soon.)

[`Taps`]("http://github.com/ricardochimal/taps") is great, but having to SSH into my deployment to run the `Taps` server, as well as 
figure out the proper local/remote database urls, is a pain. I knew the [`Heroku`]("http://github.com/heroku/heroku") gem
had it figured out; I present the Capistrano friendly version.

If you are new to `Taps`, check out this [introduction to `Taps`]("http://adam.blog.heroku.com/past/2009/2/11/taps_for_easy_database_transfers/") by [Adam Wiggins]("http://github.com/adamwiggins").

Installation
------------------------------------------------

    gem install cap-taffy

Usage
------------------------------------------------

### `Taffy`: Database Transfer

> _Dependency:_ The [`Taps`]("http://github.com/ricardochimal/taps") gem is required on any server(s) you'll be transferring databases to (`:app` role) including your development machine (where you'll be running `cap` tasks from). Run:

>     gem install taps

> _Dependency:_ The [`Heroku`]("http://github.com/heroku/heroku") gem is required on your development machine.

>     gem install heroku

To start, add the following to your `Capfile`

    require 'cap-taffy/db'

`Taffy` will start a `Taps` server on port 5000 by default, so make sure port 5000 (or w/e port you end up using) is open on your `:app` server(s)

Then you can use:

    cap db:push         # Or to specify a different port: cap db:push -s taps_port=4321
    cap db:pull         # Or to specify a different port: cap db:pull -s taps_port=4321
    

#### SSH Local Forwarding

> Some of you may not be able/want to open up ports on your servers. Instead, you can run:

>     ssh -N -L[port]:127.0.0.1:[port] [user]@[remote-server]
> And then run:

>     cap db:push -s taps_port=[port] -s local=true
> Substituing the appropriate values for [port], [user], and [remote-server].
> #### Sample Usage
> >     ssh -N -L4321:127.0.0.1:4321 henry@load-test
> >     cap db:push -s taps_port=4321 -s local=true

### Managing `database.yml`

> Much needed and coming soon.

Credits
------------------------------------------------
Thanks to developers of the [`Taps`]("http://adam.blog.heroku.com/past/2009/2/11/taps_for_easy_database_transfers/") gem and the [`Heroku`]("http://github.com/heroku/heroku") gem. And of course, Capistrano, awesome!