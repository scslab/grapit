require 'sinatra'
require 'json'
require 'grit'

BASE_DIR = ENV["BASE_DIR"] || "."

def with_repo(repo)
  repo = Grit::Repo.new(File.join(BASE_DIR, "#{File.join(params[:repo].split(/[\/\\]/))}"))
  yield(repo)
end

## Branches

get "/repos/:repo/branches" do
  content_type :json
  with_repo params[:repo] do |repo|
    branches = repo.branches.map do |branch|
      {
        name: branch.name,
        commit: {
          sha: branch.commit.id
        }
      }
    end
    branches.to_json
  end
end


## Tags

get "/repos/:repo/tags" do
  content_type :json
  with_repo params[:repo] do |repo|
    tags = repo.tags.map do |tag|
      {
        name: tag.name,
        commit: {
          sha: tag.commit.id
        }
      }
    end
    tags.to_json
  end
end

## TODO: get "/repos/:repo/git/tags/:sha"

## Blobs

get "/repos/:repo/git/blobs/:sha" do
  content_type :json
  with_repo params[:repo] do |repo|
    blob = repo.blob(params[:sha])
    { content: blob.data }
  end.to_json
end

## Commits

get "/repos/:repo/git/commits/:sha" do
  content_type :json
  with_repo params[:repo] do |repo|
    commit = repo.commit(params[:sha])
    {
      sha: commit.id,
      parents: commit.parents.map { |p| { sha: p.id } },
      message: commit.message,
      author: {
        date: commit.authored_date.xmlschema,
        name: commit.author.name,
        email: commit.author.email
       },
      committer: {
        date: commit.committed_date.xmlschema,
        name: commit.committer.name,
        email: commit.committer.email
      },
    }.to_json
  end
end

## References

get "/repos/:repo/git/refs" do
  content_type :json
  with_repo params[:repo] do |repo|
    repo.refs.map do |ref|
      type = ref.class.name.split("::").last.downcase
      {
        ref: "refs/#{type}s/#{ref.name}",
        object: {
          sha: ref.commit,
          type: type
        }
      }.to_json
    end
  end
end


get "/repos/:repo/git/refs/*" do
  content_type :json
  ref_name = params[:splat].first
  with_repo params[:repo] do |repo|
    ref = repo.refs.select {|ref| ref_name == "#{ref.class.name.split("::").last.downcase}s/#{ref.name}"}.first
    type = ref.class.name.split("::").last.downcase
    {
      ref: "refs/#{type}s/#{ref.name}",
      object: {
        sha: ref.commit,
        type: type
      }
    }.to_json
  end
end

## Trees

def makeTree(t)
  {
    path: t.name,
    mode: t.mode,
    type: "tree",
    sha: t.id
  }
end

def makeBlob(t)
  {
    path: t.name,
    mode: t.mode,
    type: "blob",
    size: t.size,
    sha: t.id
  }
end

get "/repos/:repo/git/trees/:sha" do
  content_type :json
  with_repo params[:repo] do |repo|
    tree = repo.tree(params[:sha])
    sub_trees = tree.trees.map {|t| makeTree(t)}
    blobs = tree.blobs.map {|t| makeTree(t)}
    {
      sha: tree.id,
      tree: sub_trees + blobs
    }.to_json
  end
end

