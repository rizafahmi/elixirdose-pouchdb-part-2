# Create Journal App With CouchDB

## Introduction

I personally really like the idea behind PouchDB since we cover [PouchDB here in this article](#).
We can create real-time application using this kind of technologies. Also, it's support offline
app that will sync to database server when internet available.
So let's dig deeper and build 'real' app out of it.

In this article we will create journal app using PouchDB, CouchDB and [Phoenix Web Framework](https://github.com/phoenixframework/phoenix).

## Preparing Phoenix Web Framework

Similar to last article, we will use Phoenix as the web framework. Installing Phoenix is straightforward though.

    $> git clone https://github.com/phoenixframework/phoenix.git && cd phoenix && git checkout v0.2.10 && mix do deps.get, compile
    $> mix phoenix.new pouch_journal ../pouch_journal
    $> cd ../pouch_journal
    $> mix do deps.get, compile
    $> mix phoenix.start

That's pretty much it! Now enter http://localhost:4000 on your browser. If you see "Hello world", then you're good to go.


## Installing PouchDB

Let's create html file first for our view.

    $> mkdir -p priv/views/
    $> vim priv/views/index.html

And fill the html file with this boilerplate below.

    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <title>Welcome to Pouch Journal</title>
    </head>
    <body>
      <h1>Hello PouchDB!</h1>
    </body>
    </html>

Then we need to download pouchdb javascript file [here](https://github.com/daleharvey/pouchdb/releases/download/2.2.0/pouchdb-2.2.0.min.js) and put it inside `priv/static/js` directory. Don't forget to include this pouchdb script in the `index.html` file.


    <head>
      <meta charset="UTF-8">
      <title>Welcome to Pouch Journal</title>
      <script src="/static/js/pouchdb-2.2.0.min.js"></script>
    </head>


Last step in this section is to wired it up to controller.

    defmodule PouchJournal.Controllers.Pages do
      use Phoenix.Controller

      def index(conn) do
        html conn, File.read!(Path.join(["priv/views/index.html"]))
      end
    end

Restart the web server. Go to localhost:4000 once again. You should see our html load just fine.
To trying out that pouchdb, open the javascript console or inspect element console then type this
code below:

    >> var db = new PouchDB('blogs');
    undefined
    >> console.log(db)

You should not see any error at all which mean that our setup is perfect and we should proceed to the next section.
One more thing before we proceed, let's add one javascript file called `priv/static/js/app.js` and embed it in our `index.html`.

    $> touch priv/static/js/app.js
    $> vim priv/views/index.html

    
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <title>Welcome to Pouch Journal</title>
      <script src="/static/js/pouchdb-2.2.0.min.js"></script>
      <script src="/static/js/app.js></script>
    </head>
    <body>
      <h1>Hello PouchDB!</h1>
    </body>
    </html>



All is good, proceed...


## Using PouchDB

### Creating a Database

We will start creating our database to record our journal. We create our database inside
`app.js` file.

    var db = new PouchDB('journals');
    var remoteCouch = false;

Simple enough, right?! Let's refresh our browser and make sure there is no error in 
javascript console.


### Add Journal to The Database

After creating a database, we need to add journal entry into the database. Let's create
a function for this purpose.

    function addJournal() {
      var title = document.getElementById('title').value;
      var text = document.getElementById('text').value;
      var journal = {
        title: title,
        text: text,
        publish: true
      };

      db.post(journal, function callback(err, result) {
        if (!err) {
          console.log("Successfully add a journal");
          document.getElementById('title').value = "";
          document.getElementById('text').value = "";
  
        }
      });
    }


And then create a form when user fill and click save button it will triggered `addJournal()` function.


    <body>
      <h1>Hello PouchDB!</h1>
      <input type="text" name="title" placeholder="Insert your journal's title" autofocus id="title">
      <input type="text" name="text" id="text" placeholder="Start your journal here...">
      <button type="submit" onclick="addJournal()">Save</button>
    </body>

You can try to add a journal and make sure there isn't any error inside javascript console. And if you see
message "Successfully add a journal", that mean the journal are saved.


### Show Journal List From Database

Now it's time to show list of journal that available on the database. First, we create
the function that will gather all documents from PouchDB then anytime it's called, we do redraw the UI.

    function showJournals() {
      db.allDocs({include_docs: true, descending: true}, function(err, doc) {
        redrawUI(doc.rows);
      });
    }

    function redrawUI(journals) {
      var ul = document.getElementById('journal-list');
      ul.innerHTML = '';
      journals.forEach(function(journal) {
        var li = document.createElement('li');
        var text = document.createTextNode(journal.doc.title + " - " + journal.doc.text);
        li.appendChild(text);
        ul.appendChild(li);
      });
    }

    showJournals();

Before we forget, let's add an empty `ul` element to the html file.

    <ul id="journal-list">

    </ul>


### Update The UI

We do not want to refresh the page everytime the database changes, especially when 
we do sync with server side database (CouchDB). Fortunately, PouchDB has an API for this.
It's called `db.changes` that will subscribe database changes. Let's implement this.


    var remoteCouch = false;

    db.info(function (err, info){
      db.changes({
        since: info.update_seq,
        live: true
      }).on('change', showJournals);
    });


Now refresh the page and try to add new entry to the journal and see what happen. The UI automatically update itself, right?!
It's kinda cool! Now let's do sync with CouchDb and see if it still automatically update the UI.

## Preparing The CouchDB

I assume that you already installed CouchDB so let's enable CORS so CouchDB and PouchDB
can 'talk' directly.

    $> export HOST=http://localhost:5984
    $> curl -X PUT $HOST/_config/httpd/enable_cors -d '"true"'
    $> curl -X PUT $HOST/_config/cors/origins -d '"*"'
    $> curl -X PUT $HOST/_config/cors/credentials -d '"true"'
    $> curl -X PUT $HOST/_config/cors/methods -d '"GET, PUT, POST, HEAD, DELETE"'
    $> curl -X PUT $HOST/_config/cors/headers -d '"accept, authorization, content-type, origin"'

### Basic Sync

We can use PouchDB's `replicateTo` and `replicateFrom` to transfer all the documents
to and from CouchDB or our remote database.

    var remoteCouch = "http://localhost:5984/journals";
    var opts = {live: true};
    db.replicate.to(remoteCouch, opts);
    db.replicate.from(replicateFrom, opts);

One more ingredient to make sure that PouchDB doing sync indefinetely is `live: true` flag.
It's all set! Now our database is sync. So if we doing something inside our couchdb or add new
journal from our page, it's all automatically will update the UI without refresh the page or
naively using `setTimeout` to refresh the UI like we did in the first article.

Now let's try to delete documents using CouchDB Futon Admin Site `http://localhost:5984/_utils` and
you'll see the UI will updated. Even better, if you open another browser it also will sync each other data.


## Conclusion
With just a little effort we able to create a real-time app using PouchDB ,CouchDB, and little help from JavaScript.
Not even using jQuery, just plain vanilla Javascript. This approach will be
very suitable for application like chatting or something like that.

We can take this approach and enrich the app by using jQuery or even better using one of Javascript framework like
AngularJS, Backbone or anything else. And sure, the UI is ugly. We can use one of CSS Framework like Twitter Bootstrap or 
Semanti UI, my new favorite. See you next time.
