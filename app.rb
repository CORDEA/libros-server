# Copyright 2017 Yoshihiro Tanaka
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

  # http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Author: Yoshihiro Tanaka <contact@cordea.jp>
# date  :2017-01-01

require 'json'
require 'net/http'
require 'rexml/document'
require 'sinatra'
require 'sinatra/activerecord'

class Book < ActiveRecord::Base
end

raise "The table 'books' doesn't exist." if !Book.table_exists?

class App < Sinatra::Base

  BOOK_SEARCH_API_URL =
    "http://iss.ndl.go.jp/api/sru?operation=searchRetrieve&query=isbn=%s"

  before do
    content_type :json
  end

  get '/books' do
    @books = Book.all
    { :status => 1, :books => @books }.to_json
  end

  get '/search/book' do
    code = params['code']
    return { :status => 0 }.to_json if code.blank?
    book = searchBook(code)
    return { :status => 0 }.to_json if book.nil?
    { :status => 1, :book => book }.to_json
  end

  post '/book' do
    request.body.rewind
    book = JSON.parse(request.body.read, object_class: Book)
    if validate(book) then
      book.save
      return { :status => 1, :book => book }.to_json
    end
    { :status => 0 }.to_json
  end

  patch '/book' do
    request.body.rewind
    data = JSON.parse(request.body.read, object_class: Book)
    @book = Book.find(data.id)
    @book.code = data.code
    @book.title = data.title
    @book.author = data.author
    @book.publisher = data.publisher
    @book.save
    { :status => 1, :book => @book }.to_json
  end

  delete '/book/:id' do |id|
    Book.find(id).destroy
    { :status => 1 }.to_json
  end

  def validate(book)
    return !book.code.blank? && !book.title.blank?
  end

  def searchBook(code)
    url = URI.parse(BOOK_SEARCH_API_URL % [code])
    req = Net::HTTP::Get.new(url.to_s)
    res = Net::HTTP.start(url.host, url.port) do |http|
      http.request(req)
    end
    parseXml(code, res.body)
  end

  def parseXml(code, body)
    xml = REXML::Document.new(body)
    ele = xml.elements['searchRetrieveResponse/records']
    return nil if ele.elements.size == 0
    childXml = REXML::Document.new(ele.elements['record/recordData'].text)
    data = childXml.elements['srw_dc:dc']
    Book.new(
      :code => code,
      :title => data.elements['dc:title'].text,
      :author => data.elements['dc:creator'].text,
      :publisher => data.elements['dc:publisher'].text
    )
  end

end
