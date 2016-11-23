
require "minitest"
require "minitest/autorun"
require "mocha/mini_test"
require "elastic_search"
require "active_record"
require "factory_girl"
require "yaml"

ActiveRecord::Base.establish_connection YAML.load_file(File.expand_path("../database.yml", __FILE__))

ElasticSearch::Config[:environment] = "test"

ActiveRecord::Base.connection.execute "DROP TABLE IF EXISTS products"

ActiveRecord::Base.connection.create_table :products do |t|
  t.string :title
  t.text :description
  t.string :category
  t.float :price
  t.integer :version, default: 1
  t.timestamps null: false
end

class Product < ActiveRecord::Base; end

FactoryGirl.define do
  factory :product
end

class ProductIndex
  include ElasticSearch::Index

  def self.mapping
    { :products => {} }
  end

  def self.type_name
    "products"
  end

  def self.model
    Product
  end

  def self.serialize(product)
    {
      id: product.id,
      title: product.title,
      description: product.description,
      category: product.category,
      price: product.price
    }
  end
end

ProductIndex.delete_index if ProductIndex.index_exists?
ProductIndex.create_index
ProductIndex.update_mapping

class TestIndex
  include ElasticSearch::Index

  def self.mapping
    {
      test: {
        properties: {
          test_field: { type: "string" }
        }
      }
    }
  end

  def self.type_name
    "test"
  end
end

TestIndex.delete_index if TestIndex.index_exists?

class ElasticSearch::TestCase < MiniTest::Test
  include FactoryGirl::Syntax::Methods

  def self.should_delegate_method(method, to:, subject:)
    define_method :"test_delegate_#{method}_to_#{to}" do
      assert subject.respond_to?(method), "subject doesn't respond to #{method}"

      target = subject.send(to)

      assert target.respond_to?(method), "#{to} doesn't respond to #{method}"

      mock_target = mock
      mock_target.expects(method)

      subject.stubs(to).returns(mock_target)

      params = subject.method(method).arity.abs.times.map { |i| "param-#{i}" }

      subject.send(method, *params)
    end
  end

  def self.should_delegate_methods(*methods, to:, subject:)
    methods.each do |method|
      should_delegate_method method, to: to, subject: subject
    end
  end

  def assert_difference(expressions, difference = 1, &block)
    callables = Array(expressions).map { |e| lambda { eval(e, block.binding) } }

    before = callables.map(&:call)

    res = yield

    Array(expressions).zip(callables).each_with_index do |(code, callable), i|
      assert_equal before[i] + difference, callable.call, "#{code.inspect} didn't change by #{difference}"
    end

    res
  end

  def assert_no_difference(expressions, &block)
    assert_difference(expressions, 0, &block)
  end

  def assert_present(object)
    assert object.present?, "should be present"
  end

  def assert_blank(object)
    assert object.blank?, "should be blank"
  end

  def refute_present(object)
    refute object.present?, "shouldn't be present"
  end

  def refute_blank(object)
    refute object.blank?, "shouldn't be blank"
  end

  def setup
    ProductIndex.delete Product.all
    Product.delete_all
  end
end

