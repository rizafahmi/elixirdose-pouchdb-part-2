defmodule PouchJournal.Router do
  use Phoenix.Router

  plug Plug.Static, at: "/static", from: :pouch_journal
  get "/", PouchJournal.Controllers.Pages, :index, as: :page
end
