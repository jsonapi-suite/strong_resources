### Getting Started

Add the mixin:

```ruby
class ApplicationController < ActionController::Base
  include StrongResources::Controller::Mixin
end
```

Define your resources:

```ruby
# config/initializers/strong_resources.rb
StrongResources.configure do
  strong_resource :person do
    attribute :name, :string
    attribute :age, :integer
  end

  strong_resource :pet do
    attribute :name, :string
    attribute :type, :string
  end
end
```

These resources can now be references from your controller:

```ruby
class PeopleController < ApplicationController
  strong_resource :person do
    has_many :pets, disassociate: true, destroy: true
  end

  def create
    person = Person.new(strong_resource)
    # code
  end
end
```

We've now enabled

* Strong params with type checking
* Support for nested associations
* Support for `disassociate` and `destroy` on `update` action

Most importantly, this data can now be introspected for things like automatic documentation.

### Customizing per-action

Let's say a person's name can be created, but never changed:

```ruby
class PeopleController < ApplicationController
  strong_resource :person do
    on :update do
      remove_attribute :name
    end
  end
end
```

You can do the same for relationships. Let's say the person's `Account` can be created, but not updated from this endpoint:

```ruby
class PeopleController < ApplicationController
  strong_resource :person do
    belongs_to :account

    on :update do
      remove_relationship :account
    end
  end
end
```

### Limit attribute set

You can use `only` and `except` to limit the accepted payloads:

```ruby
class PeopleController < ApplicationController
  strong_resource :person do
    has_many :pets, only: [:type]
  end
end
```

No error will be raised when excess parameters are supplied; they are silently dropped.

### Delete/Destroy

We follow the pattern where the `disassociate` parameter is for disassociation, the `destroy` parameter is for deleting the associated resource as well as disassociating. Use `disassociate` and `destroy`:

```ruby
class PeopleController < ApplicationController
  strong_resource :person do
    has_many :pets, delete: true, destroy: false
  end
end
```

These will only be available on the `update` action. To customize, define your own `update_action?`:

```ruby
def update_action?
  %w(promote update).include?(action_name)
end
```

### Relationships

Relationships can be nested to any level:

```ruby
class PeopleController < ApplicationController
  strong_resource :person do
    has_many :pets do
      belongs_to :animal_family
    end
  end
end
```

If a relationship name does not match the strong resource name, use `resource`:

```ruby
class PeopleController < ApplicationController
  strong_resource :person do
    has_many :pets, resource: :animal
  end
end
```

### Conditional Attributes

Let's say only admins can change a person's age:

```ruby
# config/initializers/strong_resources.rb
strong_resource :person do
  attribute :age, :integer, if: ->(controller) { controller.current_user.admin? }
end
```

### Custom Types

Define a custom type by giving its internal name, stronger_parameters type, and swagger type:

```ruby
# config/initializers/strong_resources.rb
Parameters = ActionController::Parameters
strong_param :pet_type, swagger: :string, type: Parameters.enum('Dog', 'Cat')

strong_resource :pet do
  attribute :type, :pet_type
end
```

This will adhere to `ActionController::Parameters.action_on_invalid_parameters` defined by stronger_parameters.
