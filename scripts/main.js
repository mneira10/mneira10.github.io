function main() {
    console.log('Ready to go!')
    $('#mandelbrot').on('click', function () {
        window.location.href = "./miniProjects/mandelbrot/index.html";
    })
    $('#circles').on('click', function () {
        window.location.href = "./miniProjects/circles/index.html";
    })
    $('#gol').on('click', function () {
        window.location.href = "./miniProjects/gol/index.html";
    })
}


$(document).ready(main);