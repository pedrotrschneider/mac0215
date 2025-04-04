# Referência da Linguagem Yupii Script

Esse documento é a referência de usuário da linguagem. Como Yupii Script é fortemente baseada em Odin, esse documento se trata de uma seleção de features específicas de odin (retiradas da página de [Overview de Odin](https://odin-lang.org/docs/overview/)). Se uma funcionalidade está listada na página de Odin mas não está listada aqui, é por que ela provavelmente não será implementada. Funcinalidades que estão previstas para o futuro mas não fazem parte do escopo atual do projeto serão explicitamente mencionadas.

## Programa básico "Hello World"

```odin
import "core:fmt"

// Esta linha é um comentário e será ignorada
/*
    Blocos de comentários também poderão ser utilizados
    /*
        Blocos de comentários podem ser encadeados
    */
*/

main :: proc() {
    fmt.println("Hello World")
}
```

- A palavra chave `import` é utilizada para trazer para o escopo principal algum outro pacote. No caso do exemplo, o pacote `core` fará parte da biblioteca padrão da linguagem;

- O símbolo `::` é utilizado para fazer a declaração de uma constante. Nesse caso, foi utilizado para declarar um procedimento (identificado pela palavra chave `proc()`) chamado `main`;

- O símbolo `//` será utilizado para comentários de apenas uma linha e os símbolos `/*` e `*/` serão utilizados para comentários de múltiplas linhas (que poderão ser encadeados);

- A linguagem não fará uso do símbolo `;` para identificar o final de uma expressão.

## Declarações de variáveis

`x` é uma variável do tipo `int` inicializada com o valor de `10`. `y` e `z` são ambas variáveis do tipo `int` que serão inicializadas com o valor padrão (no caso do tipo `int` o valor é 0).

```odin
x: int = 10
y, z: int
```
Declarações de variáveis devem ser únicas dentro de um escopo.

```odin
x: int = 10
x := 20 // ERRO: `x` está sendo re-declarado dentro do escopo atual
y, z : int = 30
test, z := 20, 30 // ERRO: `z` está sendo re-declarado dentro do escopo
```

## Declaração de atribuição

O operador de atribuição é o `=`.

```odin
x: int = 10
x = 123
```

Ele pode ser usado para atribuição de múltiplas variáveis.

```odin
x, y := 1, "hello"
y, x = "world", 2
```

Note que `:=` é composto por dois símbolos: `:` e `=`. Todas essas expressões são equivalentes:

```odin
x: int = 123
x:     = 123
x := 123
```

Caso o tipo não seja especificado após o `:`, ele será inferido a partir da atribuição.

## Declaração de constantes

Constantes são símbolos que possuem um valor atribuído e não podem ser modificadas. `x` é do tipo inferido `string` e possui o valor constante `"what"`. Constantes também podem ser tipadas explicitamente, como é o caso de `y`.

```odin
x :: "what"
y : int : 123
```

## Pacotes

Pacotes consistem em um diretório na hierarquia de arquivos contendo um ou mais arquivos Yupii Script. Todos os scripts dentro do mesmo diretório fazem parte do mesmo pacote e são visíveis entre si. Outros pacotes precisam ser explicitamente importados por meio da palavra chave `import`. A palavra chave `import` também permite renomear os pacotes caso seja desejado:

```odin
import "core:fmt"
import rl "vendor:raylib"
```

No exemplo acima, dois pacotes estão sendo importados: `"core:fmt"` e `"vendor:raylib"` (que foi renomeado para `rl`). Em Odin, seria necessário especificar o nome do pacote no começo do arquivo. Em Yupii Script isso é feito automaticamente. O nome de cada pacote será o nome da pasta que o contém.

Os nomes `core` e `vendor` nesse caso são nomes reservados para pacotes que a biblioteca padrão de Yupii Script irá prover. Caso deseje importar um pacote próprio, utilize o caminho relativo da pasta do pacote.

### Gerenciamento de símbolos exportados

Todas as declarações de um pacote são, por padrão, públicas para outros pacotes que o importarem. Caso deseje tornar alguma declaração privada, poderá ser utilziada a expressão `@(private)`

```odin
@(private)
minha_variavel_privada: int

@(private="file")
minha_variavel_privada_do_arquivo: int

@(private="package") // equivalente a @(private)
minha_variavel_privada_do_pacote: int
```

## Controle de fluxo

### Declaração `for`

#### Forma básica

A forma basica da declaração `for` é muito semelhante a outras linguages da família de `C/C++`.

```odin
for i := 0; i < 10; i += 1 {
    fmt.println(i)
}
```

Note que parêntesis `()` não são utilizados, e sempre é necessário utilizar ou chaves `{}` ou a palavra chave `do` caso deseje fazer um `for` em apenas uma linha.

```odin
for i := 0; i < 10; i += 1 { fmt.ptinln(i) }
for i := 0; i < 10; i += 1 do fmt.ptinln(i) 
```

As declarações iniciais e finais não são necessárias.

```odin
i := 0
for ; i < 10; {
    fmt.println(i)
    i += 1
}
```

Nesse caso, os símbolos `;` também podem ser omitidos, transformando o `for` no `while` tradicional de outras linguagens.

```odin
i := 0
for i < 10 {
    fmt.println(i)
    i += 1
}
```

Caso nenhuma declaração seja adicionada após o `for`, ele se torna um laçco infinito e deve ser finalizado com um `break`.

```odin
i := 0
for {
    if i >= 10 do break
    
    fmt.println(i)
    i += 1
}
```

#### Iteração sobre intervalo

Não decidi ainda se essa feature está dentro do escopo deste projeto

### Declaração `if`

Assim como `for`, os `if`s em Yupii Script não utilizam `()`, mas precisam ter ou `{}` ou `do`.

```odin
if x < 0 {
    fmt.println("x é menor que zero")
}

if x < 0 do fmt.println("x é menor que zero")
```

Assim como o `for`, é possível adicionar uma declaração inicial para um `if`. Variáveis declaradas nessa expressão inicial estarão disponíveis apenas dentro do escopo do `if` e de outros `else` encadeados.

```odin
if x := foo(); x < 0 {
    fmt.println("x é menor que zero")
} else if x == 0 {
    fmt.println("x é igual a zero")
} else {
    fmt.println("x é maior que zero")
}
```

### Declaração `switch`

`switch` inicialmente não estará incluso no escopo do projeto

### Declaração `defer`

Uma expressão iniciada com `defer` será deferida até o final do escopo atual de execução. O código asseguir irá imprimir `4` e depois `234`.

```odin
import "core:fmt"

main :: proc() {
    x := 123
    defer fmt.println(x)
    {
        defer x = 4
        x = 2
    }
    fmt.println(x)

    x = 234
}
```

É possível utilizar `defer` em um bloco inteiro.

```odin
{
    defer {
        foo()
        bar()
    }
    defer if cond {
        bar()
    }
}
```

Chamadas consecutivas a `defer` dentro de um mesmo escopo são tratadas como uma pilha. Ou seja, são executados na ordem reversa que são chamados. O código asseguir irá imprimir `3`, depois `2` e por fim `1`.

```odin
defer fmt.println("1")
defer fmt.println("2")
defer fmt.println("3")
```

### Declarações `when`

Esse tipo de declaração está fora do escopo atual do projeto.

### Declarações `break`

A declaração `break` é utilizada para finalizar prematuramente a execução de um bloco de código. São mais utilizadas no contexto de declarações `for` e `switch`.

```odin
for cond {
    switch {
    case:
        if cond {
            break // Sairá da declaração `switch`
        }
    }

    break // sairá da declaração `for`
}

loop: for cond1 {
    for cond2 {
        break loop // é possível especificar um rótulo para sair de um escopo específico
    }
}

exit: {
    if true {
        break exit // o rótulo pode ser colocado em qualquer bloco arbitrário de código
    }
    fmt.println("Essa linha nunca será executada.")
}
```

### Declarações `continue`

Declarações continue podem ser utilizadas para condicinoalmente avançar uma iteração em um laço `for`

```odin
for cond {
    if get_foo() {
        continue
    }
    fmt.println("Hello World")
}
```

### Declaração `fallthrough`

Como declarações `switch` estão fora de escopo para o projeto, declarações `fallthrough` também não serão implementadas.

## Procedimentos

Procedimentos em Yupii Script são equivalentes a funções em outras linguagens. A declaração de um procedimento literal é feito utilizando a palavra chave `proc`.

```odin
fibonacci :: proc(n: int) -> int {
    if n < 1 do return 0
    if n == 1 do return 1
    return fibonacci(n-1) + fibonacci(n-2)
}

fmt.println(fibonacci(3)) // Irá imprimir `2`
```

### Parâmetros

Em Yupii Script, procedimentos podem ter um ou mais parâmetros.

```odin
multiply :: proc(x: int, y: int) -> int {
    return x * y
}
```

Em Odin, caso dois ou mais parâmetros consecutivos possuam o mesmo tipo, é possível declarar o tipo apenas ao final da listagem. Essa funcionalidade está fora do escopo atual do projeto.

```odin
multiply :: proc(x, y: int) -> int {
    return x * y
}
```

Assim como em `C/C++`, todos os parâmetros são passados por valor ao invés de por referência (como ocorre em `Java`, por exemplo). Adicionalmente, parâmetros são imutáveis por padrão. Ao passar um ponteiro como parâmetro de um procedimento, por exemplo, o ponteiro será copiado, mas os dados internos do ponteiro não serão. Caso seja desejável modificar o valor de um parâmetro, é necessaário utilizar mutabilidade explícita.

```odin
foo :: proc(x: int) {
    x := x // mutabilidade explícita
    for x > 0 {
        fmt.println(x)
        x -= 1
    }
}
```

Procedimentos variádicos estão fora do escopo para o projeto atualmente.

### Resultados mútliplos

Procedimentos podem retornar múltiplos valores.

```odin
swap :: proc(x, y: int) -> (int, int) {
    return y, x
}
a, b := swap(1, 2)
fmt.println(a, b) // 2 1
```

### Resultados nomeados

Os resultados de um procedimento podem ser nomeados na assinatura do procedimento e pdoerão ser utilizados diretamente dentro do procedimento sem serem declarados

```odin
do_math :: proc(input: int) -> (x: int, y: int) {
    x = 2 * input + 1
    y = 3 * input / 5
    return x, y
}
```

Caso todos os resultados sejam nomeados, é possível chamar `return` vazio. Nesse caso, os resultados nomeados serão automaticamente retornados.

```odin
do_math_with_naked_return :: proc(input: int) -> (x, y: int) {
    x = 2 * input + 1
    y = 3 * input / 5
    return
}
```

### Arguemntos nomeados

Na chamada de um procedimento, é possível utilizar argumentos posicionais ou argumentos nomeados. Uma sequência de argumentos nomeados deve estar no final da listagem de argumentos da chamada do procedimento.


```odin
sum :: proc(a, b, c, d, e, f: int) -> int {
    return a + b + c + d + e + f
}

sum(1, 2, 3, 4, 5, 6) // Chamada válida utilizando argumentos posicionais
sum(a=1, b=2, c=3, d=4, e=5, f=6) // Chamada válida utilizando argumentos nomeados
sum(1, 2, f=6, c=3, d=4, b=2, e=5) // Chamada válida utilizando ambos

sum(1, 2, c=3, d=4, 5, 6) // Chamada inválida. Não é possível adicionar argumentos posicionais depois de um ou mais argumentos nomeados
```

### Valores padrão para argumentos

A declaração de um procedimento pode incluir valores padrão para os argumentos. Nesse caso, os argumentos que possuem valores padrão se tornam opcionais.

```odin
sum :: proc(a, b := 0, c := 0, d := 0, e := 0, f := 0) -> int {
    return a + b + c + d + e + f
}

sum(10, 20) // Chamada válida pois todos os arguemntos subsequentes possuem valores padrão
sum(a=10, f=60) // Chamada válida pois todos os outros argumentos possuem valores padrão
sum(1, 2, f=6, e=5) // Chamada válida pois todos os argumentos omitidos possuem valores padrão
```

### Procedimentos encadeados

Em Yupii Script, procedimentos podem ser encadeados dentro de outros procedimentos. Procedimentos encadeados só podem ser acessados dentro do procedimento onde eles foram declarados.

```odin
import "core:fmt"

main :: proc() {
    say_hello :: proc() {
        fmt.println("Hello World")
    }

    say_hello()
}
```

### Sobrecarga explícita de procedimentos

Em Yupii Script, para simplificar o sistema de chamada de procedimentos, a sobrecarga deve ser feita explicitamente.

```odin
bool_to_string :: proc(value: bool) -> string {...}
int_to_string :: proc(value: int) -> string {...}

to_string :: proc{bool_to_string, int_to_string}

a := true
b := 1
to_string(a)
to_string(b)
```

## Tipos básicos de dados

Os tipos básicos disponíveis em Yupii Script são os seguintes:

```odin
// Booleanos
bool b8 b16 b32 b64

// Inteiros
// Com sinal
int  i8 i16 i32 i64 i128
// Sem sinal
uint u8 u16 u32 u64 u128

// Números em ponto flutuante
f16 f32 f64

// Números complexos
complex32 complex64 complex128

// Quaternions
quaternion64 quaternion128 quaternion256

// Runas representam um único caracter UTF8.
// São inteiros de 32 bits. É um tipo distinto de i32
rune

// strings
string

// Tipos específicos para reflexão em runtime
typeid
any
```

### Valores zero

Todos os tipos básicos possuem um valor zero ao qual eles são atribuídos quando não são expliciatamente inicializados.

- `0` para tipos numéricos e runas
- `false` para tipos booleanos
- `""` para strings
- `nil` para ponteiros, typeid e any

### Conversão de tipos

A expressão `Type(value)` pode ser utilizada para converter um valor `value` para o tipo `Type`.

```odin
i: int = 123
f: f64 = f64(i)
u: u32 = u32(f)
```

Nesse caso os tipos também podem ser inferidos.

```odin
i := 123
f := f64(i)
u := u32(f)
```

Todas as conversões de tipo devem ser feitas explicitamente.

#### Operador `cast`

O operador `cast` também pode ser utilizado para conversão de tipos.

```odin
i := 123
f := cast(f64)i
u := cast(u32)f
```

#### Operador `transmute`

O operador transmute não está no escopo atual do projeto.

## Operadores

### Operadores aritiméticos

Os seguintes são operadores unários.

- `+`
    - `+x` é equivalente a `0 + x`
- `-`: negação
    - `-x` é equivalente a `0 - x`
- `~`: complemento binário
    - `~x` é equivalente a `m ~ x` onde `m` é um valor de mesmo número de bits que `x` com todos os bits setados para `1`

Os seguintes são operadors binários aritméticos.

- `+`: soma
    - Tipos suportados: inteiros, enums, floats, complexos, arrays de tipos numéricos, matrizes e strings constantes
- `-`: subtração
    - Tipos suportados: inteiros, enums, floats, complexos, arrays de tipos numéricos e matrizes
- `*`: multiplicação
    - Tipos suportados: inteiros, floats, complexos, arrays de tipos numéricos e matrizes
- `/`: divisão
    - Tipos suportados: inteiros, floats, complexos e arrays de tipos numéricos
- `%`: módulo (truncado)
    - Tipos suportados: inteiros
- `%%`: resto (arredondado para baixo)
    - Tipos suportados: inteiros

Os seguintes são operadores binários lógicos por bit.

- `|`: `or` por bit
    - Tipos suportados: inteiros, enums
- `~`: `xor` por bit
    - Tipos suportados: inteiros, enums
- `&`: `and` por bit
    - Tipos suportados: inteiros, enums
- `&~`: `and-not` por bit
    - Tipos suportados: inteiros, enums
- `<<`: bit-shift para a esquerda
    - Tipos suportados: inteiro << (inteiro >= 0)
- `<<`: bit-shift para a direita
    - Tipos suportados: inteiro >> (inteiro >= 0)

### Operadores de comparação

- `==`: igualdade
- `!=`: não-igualdade
- `<`: menor que
- `<=`: menor ou igual a
- `>`: maior que
- `>=`: maior ou igual a
- `&&`: `and` lógico com **short-circuting**
- `||`: `or` lógico com **short-circuting**

> [!NOTE]
> `short-circuting` se refere ao fato de que operações encadeadas não serão avaliadas caso não seja necessário. Por exemplo, na expressão `false && foo()` o procedimento `foo()`não será chamado. De forma similar, em `true || foo()` o procedimento `foo()` também não será chamado.

Os operadores `==` e `!=` podem ser aplicados em operandos que sejam **comparáveis** e os operadores `<`, `<=`, `>` e `>=` podem ser aplicados em operadores que sejam **ordenados**.

- Booleanos são **comparáveis**;
- Inteiros são **comparáveis** e **ordenados**;
- Números de ponto flutuante são **comparáveis** e **ordenados**, como definido pela especificação IEE-754;
- Complexos são **comparáveis**;
- Quaternions são **comparáveis**;
- Runas são **comparáveis** e **ordenados**;
- Strings são **comaráveis** e **ordenadas** (em ordem alfabética runa a runa);
- Matrizes são **comparáveis**;
- Ponteiros são **comparáveis** e **ordenados**;
- Enums são **comparáveis** e **ordernados**;
- Structs são **comparáveis** caso todos os seus campos sejam **comparáveis**;
- Uniões são **comparáveis** caos todas as suas variantes sejam **comparáveis**;
- Array são **comparáveis** se os valores de seus elementos forem **comparáveis**;
- `typeid` é comparável.

### Operadores lógicos

Operadores lógicos podem ser aplicados a valores booleanos. O operando da direita é avaliado condicionalmente (`short-circuting`).

- `&&`: `and` condicional
    - `a && b` é quivalente a `b if a else false`
- `||`: `or` condicional
    - `a || b` é quivalente a `true if a else b`
- `!`: negação

### Operadores compostos de atribuição

Os seguintes são operadores aritméticos compostos de atribuição:

- `+=`: soma e atribuição
    - `a += b` é equivalente a `a = a + b`
- `-=`: subtração e atribuição
    - `a -= b` é equivalente a `a = a - b`
- `*=`: multiplicação e atribuição
    - `a *= b` é equivalente a `a = a * b`
- `/=`: divisão e atribuição
    - `a /= b` é equivalente a `a = a / b`
- `%=`: módulo (truncado) e atribuição
    - `a %= b` é equivalente a `a = a % b`
- `%%=`: resto (arredondado para baixo) e atribuição
    - `a %%= b` é equivalente a `a = a %% b`

Os seguintes são operadores lógicos por bit compostos de atribuição:

- `|=`: `or` por bit e atribuição
    - `a |= b` é equivalente a `a = a | b`
- `~=`: `xor` por bit e atribuição
    - `a ~= b` é equivalente a `a = a ~ b`
- `&=`: `and` por bit e atribuição
    - `a &= b` é equivalente a `a = a & b`
- `&~=`: `and-not` por bit e atribuição
    - `a &~= b` é equivalente a `a = a &~ b`
- `<<=`: bit-shift para a esquerda e atribuição
    - `a <<= b` é equivalente a `a = a << b`
- `>>=`: bit-shift para a direita e atribuição
    - `a >>= b` é equivalente a `a = a >> b`

Os seguintes são operadores lógicos condicionais compostos de atribuição:

- `&&=`: `and` lógico e atribuição
    - `a &&= b` é equivalente a `a = a && b`
- `||=`: `or` lógico e atribuição
    - `a ||= b` é equivalente a `a = a || b`