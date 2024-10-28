# KatyCommands

Adds some useful commands to 1.20.1. **This is designed for DredgeSMP's modpack, not general purpose usage. You might be able to adapt this for elsewhere, but you'll probably need to fork this repository and edit the source code.**

## Kdata

KData lets you allows you to store data outside of NBT or Scoreboards as meaningful data types, and perform operations on them. This is particularly useful for player-associated data, as you can't normally directly edit it and there's not an elegant way to store "sidecar" data with vanilla commands. This also should be better for performance than constantly parsing NBT strings for data types that don't represent strings.

KData is stored in a similar structure to JSON or TOML, meaning any `KDataEntry` has a key and a value and is stored on a `Table`. KTables are also KDataEntries — the key is the name of the table and the value is the list of KDataEntries under it. Ultimately, all KTables are defined under a `Namespace` table. All KData Paths must have a `Namespace` as their top level table, and cannot include more than one. Keys for KDataEntries may be strings such as `MyTable`, or may represent specific instances of entities or blocks with entity UUIDs or block positions as `Vector<Int>`.

`KData` is pass by value: editing the result of `/kdata get` will not affect the source. If you need a reference or references, there is a `KDataPath` type that stores the path to any KData.

If you use a selector as the key for a table, it is evaluated to the [UUID](https://minecraft.wiki/w/Universally_unique_identifier) as an int-array if it targets an entity or the block position if it targets a block. If the selector targets multiple entities, you will get a `Vector` of `KData` values. If the path doesn't exist, you get a `KNone` type `KData` value back, which you may be able to handle or you can just let the command you're trying to run with it fail.

## KData Garbage Collection

`Tables` that have had all of their KDataEntries removed will be cleaned up. If you want to keep one around for some reason, you need to stick in some placeholder data like `KNone`. This includes Namespaces.

`KData` associated with an entity via UUID will clean itself up if the UUID points to an entity that no longer exists. This is *not* true for players, as players should keep their data when logging off or on.

Tables named `temp` will be cleaned up. These should be used only for operations that do not take place over time. Useful for stuff like doing vector math where you don't want to keep a bunch of temporary stuff around.

## KData Parameters

KData Parameters are an extension of the vanilla `data` command objects `(block <targetPos>|entity <target>|storage <target>)`. They can be the vanilla `data` command objects, or alternatively `kdata`, a KData path. The KData path can retrieve data from a stored Lambda, but you can also write a Lambda expression out in the parameter itself with `lambda`.

KData Parameters will evaluate to `KData` instead of NBT.

The condensed syntax for them is:

`(block <targetPos>|entity <target>|storage <target>|path <kdata path>|lambda <lambda expression>)`

## Closures

Closures allow you to run a command that has been interpolated with data. They look like this:

`(<KData Parameters>) => <command>`

`entity @s Health a, #dredgecombat:Moves/@s/MoveTimer/current_move b => tellraw @a { "text": "Health: %a, Current Move: %b", "color": "#FF0064" }`

If theyre stored as KData, when they are invoked they can use relative paths, capturing the context around them. Technically a Closure activated from the chat or server outside of a Table wouldn't be a real "closure" because there's no context to capture, but that's not super important. The terms for these are rather loose anyway.

```swift
//   "data" command            KData relative                                  first arg is         second arg is 
//   object                    to this closure         Command                 interpolated here    interpolated here
//   VVVVVVVVVVVVVV            VVVVVVVVVVVVVV          VVVVVVV                       VVVVVVV                VVVVV
    (entity @s Health health, ./current_move move) run tellraw @a { "text": "Health: %health, Current Move: %move", "color": "#FF0064" }
//                    ^^^^^^                 ^^^^
//                   arg name              arg name 
```

Lambdas are closures that return the output of the command. You can think of non-Lambda closures as being "void" functions, although they output their success status like other minecraft commands do.

```swift
//   "data" command           KData relative                       first arg is        second arg is 
//   object                   to this closure         command      interpolated here    interpolated here
//   VVVVVVVVVVVVVVVV         VVVVVVVVVVVVVV          VVVVVVV          VVVVVVV                VVVVV
    (entity @s Health health, ./current_move move) => literal "Health: %health, Current Move: %move"
//                    ^^^^^^                 ^^^^  ^^ 
//                   arg name           arg name   this "=>" symbol instead
//                                                 of "run" makes this a lambda
```

Assignments are used to store the result of a Lambda in a KData entry.

```swift
//               "data" command           KData relative                      first arg is         second arg is 
//               object                   to this closure         command     interpolated here    interpolated here
//               VVVVVVVVVVVVVVVV         VVVVVVVVVVVVVV          VVVVVVV          VVVVVVV                VVVVV
    ./message = (entity @s Health health, ./current_move move) => literal "Health: %health, Current Move: %move"
//  ^^^^^^^^^                     ^^^^^^                 ^^^^
//   output                      arg name              arg name 
```

Literals are Lambdas with simpler syntax, having no parameters. This means you can assign a path's data to a literal value like this:

```swift
    ./message = "This is my literal!"
//              ^^^^^^^^^^^^^^^^^^^^^
//              this is treated the same
//              as something like:
    ./message = () => literal "This is my literal!"
```

Assignments are the only way to preserve `KData` as-is from closures. Minecraft command output doesn't support KData, so if you just run `/literal true` in chat it'll just get resolved to `0b` or `"true"` as a string. KData commands avoid running *as commands* unless you run them directly with something like `/closure` or `/literal`, which allows them to return their true `KData` values instead of resolving to command output as long as you assign the KData to something. For closures with no return value (`() run <command>` instead of `() => <command>`) this doesn't matter because you're looking to cause a side effect anyway.

## KData Types

### KData Key/Path Types

* `Table` represents a set of key-value pairs (KDataEntries).
  * `Namespace` is a required table that should be named the same as the namespace of your datapack. Only one `Namespace` can be included in a path, and it must be the top-level table.
* `KDataEntry` represents a key-value pair.
* `Path` stores a path to a `KDataEntry`. It's a vector of KDataEntry keys.
* `RelativePath` is used for Closures. When the Closure is invoked, it will insert its own path before the relative path to create a true `Path`.

|KData Type| Type identifier | Example Literal | NBT Type Conversion |
|-|-|-|-|
| Table |`table`|`{key1:"value1", key2:24}`| Compound |
| Namespace | `#` | `#namespace{<table entries>}` (A namespace is created when something is assigned to a path that includes it.) | Compound |
| KDataEntry | `entry` | `key:value` | ❌ String (as SNBT Tag, with the Key and Value converting to strings) |
| Path | `path` | `#namespace:table_key/subtable_key/entry_key` | ❌ String (from its literal representation) |
| Relative Path | `relative_path` | `../subtable_key/entry_key` | ❌ String (from its literal representation) |

### Closure Types

* `Closure` represents a command that can be run. This contains an interpolateable string. They can capture their context using Relative Path literals for their commands, implicitly adding their context to the start of the path.
* `Lambda` evaluates a command as a closure and returns the output as though it were that value.
* `Assignment` (`let`) is like a lambda that mutates a given path.
* `Literal` is a Lambda that returns whatever its Literal Expression represents, equivalent to `() => literal <literal expression>`.

|KData Type| Type identifier | Example Literal | NBT Type Conversion |
|-|-|-|-|
| Closure |`closure`|`(./GetString string) run say %string`| ❌ String (from its literal representation, ex `"(./GetString string) => say %string"`) |
| Lambda |`lambda`|`(./GetString string) => literal "this is the string: %string"`| ❓ Converts from whatever type it returns |
| Literal |`literal`| A Literal of any type | ❓ Converts from whatever type it returns |
| Assignment |`let`|`let{say hello}`| ❌ String (from its literal representation) |

### Primitives

* `String` represents a string of characters.
* `Bool` is a `true` or `false` value, a single bit integer.
* `Byte` is an 8 bit integer.
* `Int` (16, 32, or 64 bit integer, dynamically sized)
* `Float` (64 bit precision floating point number, equivalent to `double` in NBT)
* `NbtElement` represents an NBT Value of any type, useful if you don't need to mess with it too much and just want to copy around NBT.
* `None` represents nothing.

|KData Type| Type identifier | Example Literal | NBT Type Conversion |
|-|-|-|-|
| String |`string`|`string_contents`| String (from its contents) |
| Bool |`bool`|`true` or `false`| Byte (`true => 1b`, `false => 0b`)|
| Byte |`byte`|`34b`| Byte |
| Int |`int`|`985`| Short, Int, Long |
| NbtElement |`nbt`|`nbt{<SNBT literal>}`| NBT element |
| None |`none`|`none`| ❌ String (`"none"`) |

### Collections

* `Vector` represents a single-dimensional collection of Data of the same type.
  * `UUID` is an entity UUID in int-array format (four elements).
  * `BlockPos` is a Int Vector with 3 elements that represents a position quantized to the block grid.
  * `Vector3` is a Float Vector with 3 elements that represents a position, direction, force, and more.

Here is a table of the data types with their identifiers, an example literal representation, and how they convert to NBT. NBT Type Conversions marked with ❌ don't have all of their functionality in NBT.

|KData Type| Type identifier | Example Literal | NBT Type Conversion |
|-|-|-|-|
| Vector |`vector`|`["hello!","this is the second element","you'll never guess what comes next"]`| Array (Byte, Int, or Long) if applicable, List if not |
| UUID |`uuid`|`[uuid;-132296786,2112623056,-1486552928,-920753162]`| Array (Int)  |
| BlockPos |`block`|`[block;2,3,1]`| Array (Byte, Int, or Long) |
| Vector3 |`vec3`|`[vec3;6.283,3.14,1.0]`| List (Float or Double) |

Types should sensibly coerce into one another. Subtypes will coerce into their supertypes if needed (a command will coerce into a string). Other types can coerce into each other as well. For example, a Byte will coerce into an Int if needed, and a Bool will coerce into a Byte. A string will coerce into a Path. Properties will always coerce into their return values. Most types should be able to coerce into strings.

## KData Paths

Paths look like this: `#dredgecombat:Moves/@s/MoveTimer/remaining_time`

All KData Paths must start from a `Namespace`.

Paths can be stored as the `KDataPath` KData type.

KData will generally be laid out something like this.

```swift
{#dredgecombat} // <- table for the datapack namespace
    ┣━{temp} // <- data entries under here are automatically cleaned up and should not be depended on
    ┣━{Moves}
    ┃   ┣━...
    ┃   ┗━{SomeMove}
    ┃       ┗━...
    ┗━{MoveExecutors}
        ┣━...
        ┗━{[uuid;-132296786,2112623056,-1486552928,-920753162]} // <- uuid
            ┣━...
            ┗━{MoveTimer}
                ┣━current_move: #dredgecombat/Moves/SomeMove // <- this is a path, which makes this entry essentially a reference
                ┣━TickDown: let{./remaining_time from lambda{}} // <- this is a closure!
                ┗━remaining_time: 6
```

So, a path to select the `remaining_time` value would look like this:

```swift

//              selector converts
//              into UUID, the key of
// namespace    this entity's subtable 
// table key        |
//    |             |
//    V             V
#dredgecombat:Moves/@s/MoveTimer/remaining_time
//              Λ          Λ           Λ
//              |          |           |
//          table key   subtable      value
//                        key          key

```

The `@s` is evaluated to the sender's UUID if it is an entity, or the position of the block if you did `execute block`.

Closures can use relative paths. The TickDown `lambda{}`
 `./TickDown`

## /let

`/let` stores data in a KData Path. This data can be from the result of a command, lambda, NBT from a `data` command object, KData by path, or a literal.

`let <kdata path> from <kdata param>`

kdata param syntax expanded: `let <kdata path> from (block <targetPos>|entity <target>|storage <target>|path <kdata path>|lambda <lambda expression>)`

### /let with Assignment

You can also use `let` to invoke an assignment expression.

`let <assignment>`

assignment syntax expanded: `let <kdata path> = <lambda expression>`

assignment & lambda syntax expanded:

```swift
//                        lambda expression
//                     VVVVVVVVVVVVVVVVVVVVVVV
    let <kdata path> = (<params>) => <command>
//      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
//        assignment expression
```

## /literal

`/literal` outputs the value of a literal expression. Keep in mind that this command can only output what vanilla commands can on their own if ran as a normal command instead of as part of an Assignment expression.

### /literal Syntax

`literal <literal>`

### /literal Example

`literal "This is my literal!"`

returns `"This is my literal"`.

Keep in mind that this command can only output what vanilla commands can on their own if ran as a normal command. You can preserve the `KData` as-is by using a Literal Assignment instead with `/let`, or if you want to interpolate the literal you can do something like:

`let ./string_from_values = (./val0, ./val1) => literal "Val0: %val0, Val1: %val1"`

## /closure

`/closure` evaluates a Closure expression. This allows you to run a command that has been interpolated with KData Parameters. Keep in mind that this command can only output what vanilla commands can on their own, so using a Lambda as the closure may not be very useful depending on what `KData` return type you need. This is mostly for "void" closures where you don't care what the return value is, you just want to trigger some side effects (like `tellraw` or something).

### Syntax

`closure <closure expression>`

expanded to include the Closure expression syntax:

`closure (<KData Parameters>) => <command>`

### /closure Example

```swift
closure (entity @s Health health, ./current_move move) run tellraw @a { "text": "Health: %health, Current Move: %move", "color": "#FF0064" }
```

This would output something like:

`Health: 20.0, Current Move: Upwards Slash`

## /invoke

`/invoke` is the old version of `/closure` and will be removed when `/closure` is finished.

`invoke <command> with (block <targetPos>|entity <target>|storage <target>) [<path>]`

`invoke <command> with kdata <kdata path>`

### /invoke Example

`invoke "tellraw @a { \"text\": \"Interpolated Value: %s\", \"color\": \"#FF0064\" }" with entity @s Health`

Assuming you have full HP, this outputs:

`Interpolated Value: 20.0`
